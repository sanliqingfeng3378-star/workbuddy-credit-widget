import SwiftUI
import AppKit

@main
struct WorkBuddyCreditApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences: AppPreferences
    @StateObject private var monitor: CreditMonitor
    @StateObject private var loginItem = LoginItemManager()
    init() {
        let preferences = AppPreferences()
        _preferences = StateObject(wrappedValue: preferences)
        _monitor = StateObject(wrappedValue: CreditMonitor(preferences: preferences))
    }
    var body: some Scene {
        WindowGroup("WorkBuddy 积分监测", id: "dashboard") {
            Dashboard(monitor: monitor, preferences: preferences)
                .background(StartupWindowVisibility(showOnLaunch: preferences.showDashboardOnLaunch))
                .onOpenURL { _ in
                    LaunchPresentation.shared.explicitOpen()
                    NSApp.windows.first(where: { $0.identifier?.rawValue == "WorkBuddyDashboard" })?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }.defaultSize(width: 780, height: 520).windowResizability(.contentSize)
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            Label(preferences.showMenuBarBalance ? "WB \(CreditFormat.remaining(monitor.payload.snapshot))" : "WB", systemImage: "sparkle")
        }.menuBarExtraStyle(.window)
        Settings { SettingsView(preferences: preferences, loginItem: loginItem, monitor: monitor) }
            .windowResizability(.contentSize)
    }
}

struct Dashboard: View {
    @ObservedObject var monitor: CreditMonitor
    @ObservedObject var preferences: AppPreferences
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WorkBuddy 积分监测").font(.system(size: 25, weight: .bold))
                    Text("把剩余积分，放在桌面上。").foregroundStyle(.secondary)
                }
                Spacer()
                OpenSettingsButton().buttonStyle(.borderless)
            }
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    CreditCard(payload: monitor.payload).frame(width: 344, height: 170)
                    Text("深色 · 积分看板").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 9) {
                    CreditCard(payload: monitor.payload, paper: true).frame(width: 344, height: 170)
                    Text("浅色 · 纸张额度卡片").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Button("打开官网登录", action: monitor.showLogin).buttonStyle(.borderedProminent)
                Button { Task { await monitor.refresh() } } label: {
                    Label(monitor.busy ? "正在同步…" : "立即刷新", systemImage: "arrow.clockwise")
                }.disabled(monitor.busy)
                Spacer()
                Text(preferences.refreshSummary).font(.caption).foregroundStyle(.secondary)
            }
            if let message = monitor.payload.message {
                Label(message, systemImage: "info.circle").font(.callout).foregroundStyle(.orange)
            } else {
                Label(preferences.automaticRefresh ? "已连接 · 关闭窗口后仍会通过菜单栏自动同步" : "已连接 · 定时刷新已暂停，可手动刷新", systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green)
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Text("添加到桌面").font(.headline)
                Text("右键桌面 → 编辑小组件 → 搜索「WorkBuddy 积分」→ 选择深色或浅色样式。")
                Text("首次使用请在插件窗口内登录官网；桌面小组件刷新时间由 macOS 调度。")
                    .foregroundStyle(.secondary)
            }.font(.system(size: 12))
        }.padding(28).frame(width: 780)
    }
}

struct MenuContent: View {
    @ObservedObject var monitor: CreditMonitor
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(spacing: 12) {
            CreditCard(payload: monitor.payload).frame(width: 344, height: 170)
            HStack {
                Button("刷新") { Task { await monitor.refresh() } }.disabled(monitor.busy)
                Button("登录", action: monitor.showLogin)
                Button("打开面板") { LaunchPresentation.shared.explicitOpen(); openWindow(id: "dashboard"); NSApp.activate(ignoringOtherApps: true) }
                OpenSettingsButton()
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
            }.buttonStyle(.borderless).font(.caption)
        }.padding(12).frame(width: 368)
    }
}
