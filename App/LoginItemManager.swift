import Combine
import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

struct MainAppLoginItem: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

@MainActor
final class LoginItemManager: ObservableObject {
    private let service: any LoginItemService
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?
    var isRequested: Bool { status == .enabled || status == .requiresApproval }
    var statusText: String {
        switch status {
        case .enabled: return "已开启 · 登录 Mac 后自动运行"
        case .requiresApproval: return "等待系统允许，请前往系统登录项设置"
        case .notRegistered: return "未开启 · 需要时手动打开应用"
        case .notFound: return "系统尚未识别登录项，可尝试开启"
        @unknown default: return "暂时无法确认登录项状态"
        }
    }
    init(service: any LoginItemService = MainAppLoginItem()) {
        self.service = service
        status = service.status
    }
    func refreshStatus() { status = service.status }
    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval { try service.register() }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            errorMessage = "无法更改开机自启动：\(error.localizedDescription)"
        }
        refreshStatus()
    }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
