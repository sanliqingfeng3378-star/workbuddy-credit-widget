import AppKit
import SwiftUI
import WebKit
import WidgetKit

@MainActor
final class CreditMonitor: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var payload = CreditPayload.empty
    @Published var busy = false
    @Published var browserReady = false
    @Published var websiteError: String?
    let webView: WKWebView
    private var timer: Timer?
    private var lastAttempt: Date?
    private let preferences: AppPreferences
    private var loginWindow: NSWindow?
    private var accountID: String?
    private let bridge = CreditBridge()

    init(preferences: AppPreferences) {
        self.preferences = preferences
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        payload.message = "正在验证官网登录状态…"
        webView.navigationDelegate = self
        webView.uiDelegate = self
        bridge.start()
        publish()
        webView.load(URLRequest(url: URL(string: "https://www.workbuddy.cn/")!))
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if RefreshPolicy.isDue(enabled: self.preferences.automaticRefresh, minutes: self.preferences.refreshMinutes, lastAttempt: self.lastAttempt, now: Date()) {
                    await self.refresh()
                }
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.preferences.refreshOnWake else { return }
                await self.refresh()
            }
        }
    }

    func showLogin() {
        if loginWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 760), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "WorkBuddy 官网 · 登录后回到积分监测点击刷新"
            window.contentView = webView
            window.isReleasedWhenClosed = false
            window.center()
            loginWindow = window
        }
        if !browserReady { webView.load(URLRequest(url: URL(string: "https://www.workbuddy.cn/")!)) }
        loginWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        browserReady = webView.url?.host == "www.workbuddy.cn"
        websiteError = nil
        if browserReady { Task { await refresh() } }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        websiteError = "官网暂时无法加载，请检查网络后重试"
        payload.message = websiteError
        publish()
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, url.scheme == "https" {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func refresh() async {
        guard !busy else { return }
        lastAttempt = Date()
        guard browserReady, webView.url?.host == "www.workbuddy.cn" else {
            payload.message = "请先打开官网登录 WorkBuddy"
            publish()
            return
        }
        busy = true
        defer { busy = false }
        do {
            // Requests stay inside the official origin and use WebKit's own session.
            // No password, cookie or access token is read by this app or sent to the widget.
            let script = #"""
            if (location.origin !== 'https://www.workbuddy.cn') return {failure:'origin'};
            async function request(path, post=false, enterprise='') {
              const controller = new AbortController();
              const timeout = setTimeout(()=>controller.abort(), 18000);
              try {
                const headers={'Content-Type':'application/json','Accept-Language':'zh'};
                if(enterprise) headers['X-Enterprise-Id']=enterprise;
                const r=await fetch(path,{method:post?'POST':'GET',credentials:'include',headers,
                  ...(post?{body:'{}'}:{}),signal:controller.signal,redirect:'error'});
                if(r.status===401||r.status===403) return {code:401};
                if(!r.ok) return {code:r.status};
                if(!(r.headers.get('content-type')||'').includes('application/json')) return {code:401};
                return await r.json();
              } finally {clearTimeout(timeout);}
            }
            try {
              const p=await request('/console/account');
              if(p.code!==0) return {failure:'login'};
              const account=p.data?.account||p.data;
              if(!account?.uid) return {failure:'schema'};
              const enterprise=account.enterpriseId||'';
              const data=await request(enterprise?'/v2/billing/meter/get-enterprise-user-usage':'/billing/meter/get-user-resource-summary',true,enterprise);
              const p2=await request('/console/account');
              const a2=p2.data?.account||p2.data;
              if(p2.code!==0||a2?.uid!==account.uid||(a2?.enterpriseId||'')!==enterprise) return {failure:'changed'};
              return {identity:account.uid+':'+enterprise,enterprise:!!enterprise,response:data};
            } catch(e) {return {failure:'network'};}
            """#
            let result = try await webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
            guard let object = result as? [String: Any] else { throw CreditError.malformed }
            if let failure = object["failure"] as? String {
                switch failure {
                case "login", "origin": throw CreditError.login
                case "network": throw CreditError.network
                case "changed": throw CreditError.accountChanged
                default: throw CreditError.malformed
                }
            }
            guard let identity = object["identity"] as? String, let response = object["response"] as? [String: Any] else { throw CreditError.malformed }
            if accountID != identity { payload.snapshot = nil; accountID = identity }
            let snapshot = try (object["enterprise"] as? Bool == true) ? CreditParser.enterprise(response) : CreditParser.personal(response)
            payload = CreditPayload(snapshot: snapshot, message: nil)
        } catch {
            if let creditError = error as? CreditError {
                switch creditError {
                case .login, .accountChanged: payload.snapshot = nil; accountID = nil
                default: break
                }
                payload.message = creditError.localizedDescription
            } else { payload.message = "暂时无法同步，请打开官网后重试" }
        }
        publish()
    }

    private func publish() {
        do { try PayloadCache.save(payload) }
        catch { payload.message = "本地缓存写入失败，当前读数仅在应用运行时可用" }
        bridge.publish(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
