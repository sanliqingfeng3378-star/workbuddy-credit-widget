import Foundation
import ServiceManagement

final class FakeLoginItem: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var fail = false
    var registerCount = 0
    func register() throws {
        if fail { throw NSError(domain: "Test", code: 1) }
        registerCount += 1
        status = .enabled
    }
    func unregister() throws {
        if fail { throw NSError(domain: "Test", code: 2) }
        status = .notRegistered
    }
}

@main
struct SettingsTests {
    @MainActor static func main() {
        let name = "workbuddy-settings-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppPreferences(defaults: defaults)
        precondition(settings.automaticRefresh && settings.refreshOnWake && settings.showDashboardOnLaunch)
        precondition(settings.showMenuBarBalance && settings.refreshMinutes == 5)
        settings.automaticRefresh = false
        settings.refreshOnWake = false
        settings.showDashboardOnLaunch = false
        settings.showMenuBarBalance = false
        settings.refreshMinutes = 10
        let restored = AppPreferences(defaults: defaults)
        precondition(!restored.automaticRefresh && !restored.refreshOnWake && !restored.showDashboardOnLaunch)
        precondition(!restored.showMenuBarBalance && restored.refreshMinutes == 10)
        settings.refreshMinutes = -100
        precondition(settings.refreshMinutes == 5 && defaults.integer(forKey: "refreshMinutes") == 5)
        defaults.set(999, forKey: "refreshMinutes")
        precondition(AppPreferences(defaults: defaults).refreshMinutes == 5)

        let now = Date(timeIntervalSince1970: 10000)
        precondition(!RefreshPolicy.isDue(enabled: false, minutes: 1, lastAttempt: nil, now: now))
        precondition(RefreshPolicy.isDue(enabled: true, minutes: 5, lastAttempt: nil, now: now))
        precondition(!RefreshPolicy.isDue(enabled: true, minutes: 5, lastAttempt: now.addingTimeInterval(-299), now: now))
        precondition(RefreshPolicy.isDue(enabled: true, minutes: 5, lastAttempt: now.addingTimeInterval(-300), now: now))
        precondition(!RefreshPolicy.isDue(enabled: true, minutes: 10, lastAttempt: now.addingTimeInterval(-300), now: now))
        precondition(RefreshPolicy.isDue(enabled: true, minutes: 1, lastAttempt: now.addingTimeInterval(-300), now: now))

        let service = FakeLoginItem()
        let manager = LoginItemManager(service: service)
        precondition(!manager.isRequested)
        manager.setEnabled(true)
        precondition(manager.status == .enabled && service.registerCount == 1)
        manager.setEnabled(true)
        precondition(service.registerCount == 1)
        manager.setEnabled(false)
        precondition(!manager.isRequested)
        service.fail = true
        manager.setEnabled(true)
        precondition(!manager.isRequested && manager.errorMessage != nil)
        service.fail = false
        service.status = .requiresApproval
        manager.refreshStatus()
        precondition(manager.isRequested && manager.status == .requiresApproval)
        manager.setEnabled(true)
        precondition(service.registerCount == 1 && manager.errorMessage == nil)
        manager.setEnabled(false)
        precondition(!manager.isRequested)
        service.status = .enabled
        manager.refreshStatus()
        precondition(manager.isRequested)
        print("PASS: preference persistence, refresh timing, login-item errors and external status changes")
    }
}
