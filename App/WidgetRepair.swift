import AppKit
import Combine
import WidgetKit
import Darwin

enum WidgetRepairError: LocalizedError {
    case missingExtension, commandFailed, timedOut, stopFailed
    var errorDescription: String? {
        switch self {
        case .missingExtension: return "找不到本应用的桌面扩展。请将完整应用放入“应用程序”后重试。"
        case .commandFailed: return "扩展验证或注册失败。请重新安装完整应用后重试。"
        case .timedOut: return "系统响应超时，请稍后重试。"
        case .stopFailed: return "旧扩展未能退出。请稍后重试，或注销并重新登录 Mac。"
        }
    }
}

/// Operates only on the extension inside this app; never restarts system widget hosts.
enum WidgetRepairWorker {
    static func matchingPIDs(_ output: String, executable: String) -> [Int32] {
        output.split(separator: "\n").compactMap { row in
            let parts = row.trimmingCharacters(in: .whitespaces).split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2, parts[1] == executable, let pid = Int32(parts[0]), pid > 1 else { return nil }
            return pid
        }
    }

    static func run(appURL: URL) throws {
        let app = appURL.resolvingSymlinksInPath()
        let extensionURL = app.appendingPathComponent("Contents/PlugIns/WorkBuddyCreditsWidget.appex")
        guard let bundle = Bundle(url: extensionURL),
              bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "WorkBuddyCreditsWidget",
              let executable = bundle.executableURL?.resolvingSymlinksInPath(),
              executable.path == extensionURL.appendingPathComponent("Contents/MacOS/WorkBuddyCreditsWidget").path
        else { throw WidgetRepairError.missingExtension }
        _ = try command("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        _ = try command("/usr/bin/pluginkit", ["-a", extensionURL.path])
        let processes = try command("/bin/ps", ["-axo", "pid=,comm="])
        for pid in matchingPIDs(processes, executable: executable.path) {
            // Recheck the executable immediately before signalling to avoid stale PID matches.
            // PROC_PIDPATHINFO_MAXSIZE is 4 * MAXPATHLEN; the SDK macro is not imported into Swift.
            var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            guard proc_pidpath(pid, &path, UInt32(path.count)) > 0,
                  String(cString: path) == executable.path else { continue }
            if kill(pid, SIGTERM) != 0 && errno != ESRCH { throw WidgetRepairError.stopFailed }
        }
    }

    private static func command(_ path: String, _ arguments: [String]) throws -> String {
        // File-backed output avoids blocking on a full pipe when ps lists many processes.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("workbuddy-repair-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        else { throw WidgetRepairError.commandFailed }
        defer { try? FileManager.default.removeItem(at: url) }
        let output = try FileHandle(forWritingTo: url)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let ended = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in ended.signal() }
        try process.run()
        if ended.wait(timeout: .now() + 10) == .timedOut {
            process.terminate()
            if ended.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
            throw WidgetRepairError.timedOut
        }
        guard process.terminationStatus == 0 else { throw WidgetRepairError.commandFailed }
        return String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }
}

@MainActor
final class WidgetRepairManager: ObservableObject {
    static let shared = WidgetRepairManager()
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false

    private var build: String {
        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")-\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")"
    }

    func repairAfterUpdate() async {
        guard UserDefaults.standard.string(forKey: "widgetRepairBuild") != build else { return }
        await repair()
    }

    func repair() async {
        guard !busy else { return }
        busy = true
        failed = false
        message = "正在重新加载桌面卡片…"
        defer { busy = false }
        let appURL = Bundle.main.bundleURL
        do {
            try await Task.detached(priority: .userInitiated) { try WidgetRepairWorker.run(appURL: appURL) }.value
            WidgetCenter.shared.reloadTimelines(ofKind: "WorkBuddyCreditsDark")
            WidgetCenter.shared.reloadTimelines(ofKind: "WorkBuddyCreditsPaper")
            UserDefaults.standard.set(build, forKey: "widgetRepairBuild")
            message = "已请求重新加载。请稍等并切换窗口检查卡片；仍未恢复时，可注销并重新登录 Mac。"
        } catch {
            failed = true
            message = error.localizedDescription
        }
    }
}
