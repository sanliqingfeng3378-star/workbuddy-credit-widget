import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var loginItem: LoginItemManager
    @ObservedObject var monitor: CreditMonitor
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 24, weight: .medium)).foregroundStyle(.green)
                    .frame(width: 48, height: 48).background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("WorkBuddy 设置").font(.title2.bold())
                    Text("按你的习惯，让积分常驻桌面。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Divider()
            Form {
                Section {
                    Toggle(isOn: Binding(get: { loginItem.isRequested }, set: { loginItem.setEnabled($0) })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("开机自启动")
                            Text(loginItem.statusText).font(.caption).foregroundStyle(.secondary)
                        }
                    }.accessibilityIdentifier("launchAtLogin")
                    if let error = loginItem.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                    }
                    if loginItem.status == .requiresApproval || loginItem.errorMessage != nil || loginItem.status == .notFound {
                        Button("打开系统登录项设置", action: loginItem.openSystemSettings)
                    }
                    Toggle("启动时显示积分面板", isOn: $preferences.showDashboardOnLaunch)
                        .help("关闭后，下次启动仅显示菜单栏图标；可从菜单栏重新打开面板。")
                    Toggle("菜单栏显示剩余积分", isOn: $preferences.showMenuBarBalance)
                } header: { Label("启动与显示", systemImage: "macwindow") }
                Section {
                    Toggle("定时自动刷新", isOn: $preferences.automaticRefresh)
                    Picker("刷新间隔", selection: $preferences.refreshMinutes) {
                        ForEach(RefreshPolicy.allowedMinutes, id: \.self) { Text("\($0) 分钟").tag($0) }
                    }.disabled(!preferences.automaticRefresh)
                    Toggle("电脑唤醒后刷新", isOn: $preferences.refreshOnWake)
                    HStack {
                        Text("立即获取最新积分").foregroundStyle(.secondary)
                        Spacer()
                        Button(monitor.busy ? "正在刷新…" : "立即刷新") { Task { await monitor.refresh() } }
                            .disabled(monitor.busy)
                    }
                } header: { Label("积分同步", systemImage: "arrow.triangle.2.circlepath") }
                footer: {
                    Text("定时刷新与唤醒刷新可分别设置。启动、登录完成及手动刷新仍会同步。桌面卡片的显示更新由 macOS 调度，可能稍有延迟。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WorkBuddy 积分")
                            Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") · 非腾讯官方项目")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Link("使用说明", destination: URL(string: "https://github.com/sanliqingfeng3378-star/workbuddy-credit-widget#readme")!)
                    }
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text("设置自动保存到本机").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 24).padding(.vertical, 14)
        }
        .frame(width: 540, height: 650)
        .onAppear { loginItem.refreshStatus(); NSApp.activate(ignoringOtherApps: true) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refreshStatus()
        }
    }
}

struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Button { NSApp.activate(ignoringOtherApps: true); openSettings() } label: {
            Label("设置", systemImage: "gearshape")
        }.help("打开设置（⌘,）")
    }
}

/// Apply the saved initial window preference once, without hiding later opens.
@MainActor
final class LaunchPresentation {
    static let shared = LaunchPresentation()
    var handledInitialWindow = false
    func explicitOpen() { handledInitialWindow = true }
}

struct StartupWindowVisibility: NSViewRepresentable {
    let showOnLaunch: Bool
    func makeNSView(context: Context) -> WindowObserver { WindowObserver(showOnLaunch: showOnLaunch) }
    func updateNSView(_ nsView: WindowObserver, context: Context) {}
    final class WindowObserver: NSView {
        let showOnLaunch: Bool
        init(showOnLaunch: Bool) { self.showOnLaunch = showOnLaunch; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("Not used") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.identifier = NSUserInterfaceItemIdentifier("WorkBuddyDashboard")
            guard !LaunchPresentation.shared.handledInitialWindow else { return }
            LaunchPresentation.shared.handledInitialWindow = true
            if !showOnLaunch {
                DispatchQueue.main.async { [weak window] in window?.orderOut(nil) }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LaunchPresentation.shared.explicitOpen()
        if !flag, let dashboard = sender.windows.first(where: { $0.identifier?.rawValue == "WorkBuddyDashboard" }) {
            dashboard.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }
}
