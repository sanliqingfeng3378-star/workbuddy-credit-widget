import SwiftUI
import AppKit

@main
struct WorkBuddyCreditApp: App {
    @StateObject private var monitor = CreditMonitor()
    var body: some Scene {
        WindowGroup("WorkBuddy 积分监测", id: "dashboard") {
            Dashboard(monitor: monitor)
                .onOpenURL { _ in NSApp.activate(ignoringOtherApps: true) }
        }.defaultSize(width: 780, height: 520).windowResizability(.contentSize)
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            Label("WB \(CreditFormat.remaining(monitor.payload.snapshot))", systemImage: "sparkle")
        }.menuBarExtraStyle(.window)
    }
}

struct Dashboard: View {
    @ObservedObject var monitor: CreditMonitor
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WorkBuddy 积分监测").font(.system(size: 25, weight: .bold))
                    Text("把剩余积分，放在桌面上。").foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkle").font(.system(size: 36)).foregroundStyle(.green)
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
                Text("每 5 分钟查询").font(.caption).foregroundStyle(.secondary)
            }
            if let message = monitor.payload.message {
                Label(message, systemImage: "info.circle").font(.callout).foregroundStyle(.orange)
            } else {
                Label("已连接 · 关闭窗口后仍会通过菜单栏自动同步", systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green)
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
                Button("打开面板") { openWindow(id: "dashboard"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
            }.buttonStyle(.borderless).font(.caption)
        }.padding(12).frame(width: 368)
    }
}
