import Foundation
import Combine

final class AppPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var showDashboardOnLaunch: Bool { didSet { defaults.set(showDashboardOnLaunch, forKey: "showDashboardOnLaunch") } }
    @Published var showMenuBarBalance: Bool { didSet { defaults.set(showMenuBarBalance, forKey: "showMenuBarBalance") } }
    @Published var automaticRefresh: Bool { didSet { defaults.set(automaticRefresh, forKey: "automaticRefresh") } }
    @Published var refreshOnWake: Bool { didSet { defaults.set(refreshOnWake, forKey: "refreshOnWake") } }
    @Published var refreshMinutes: Int {
        didSet {
            let validated = RefreshPolicy.validatedMinutes(refreshMinutes)
            if refreshMinutes != validated { refreshMinutes = validated; return }
            defaults.set(refreshMinutes, forKey: "refreshMinutes")
        }
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["showDashboardOnLaunch": true, "showMenuBarBalance": true,
                                     "automaticRefresh": true, "refreshOnWake": true, "refreshMinutes": 5])
        showDashboardOnLaunch = defaults.bool(forKey: "showDashboardOnLaunch")
        showMenuBarBalance = defaults.bool(forKey: "showMenuBarBalance")
        automaticRefresh = defaults.bool(forKey: "automaticRefresh")
        refreshOnWake = defaults.bool(forKey: "refreshOnWake")
        refreshMinutes = RefreshPolicy.validatedMinutes(defaults.integer(forKey: "refreshMinutes"))
    }
    var refreshSummary: String {
        automaticRefresh ? "每 \(refreshMinutes) 分钟查询" : "定时刷新已暂停"
    }
}
