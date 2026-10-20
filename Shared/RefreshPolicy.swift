import Foundation

/// Keep polling bounded, including after an error or a user changing settings.
enum RefreshPolicy {
    static let allowedMinutes = [1, 5, 10, 15]
    static func validatedMinutes(_ value: Int) -> Int {
        allowedMinutes.contains(value) ? value : 5
    }
    static func isDue(enabled: Bool, minutes: Int, lastAttempt: Date?, now: Date) -> Bool {
        guard enabled else { return false }
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= Double(validatedMinutes(minutes) * 60)
    }
}
