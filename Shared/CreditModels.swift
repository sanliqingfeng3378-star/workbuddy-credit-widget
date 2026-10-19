import Foundation

struct CreditPackage: Codable, Identifiable {
    var id: String
    var name: String
    var remaining: Double
    var total: Double
    var used: Double
}

struct CreditSnapshot: Codable {
    var remaining: Double
    var total: Double
    var used: Double
    var plan: String
    var packages: [CreditPackage]
    var updatedAt: Date
    var unlimited = false
    var fraction: Double { unlimited ? 1 : total > 0 ? min(1, max(0, remaining / total)) : 0 }
    var isStale: Bool { Date().timeIntervalSince(updatedAt) > 15 * 60 }
    static let preview = CreditSnapshot(remaining: 3177.5, total: 4000, used: 822.5, plan: "标准版", packages: [], updatedAt: Date())
}

struct CreditPayload: Codable {
    var snapshot: CreditSnapshot?
    var message: String?
    static let empty = CreditPayload(snapshot: nil, message: "打开应用，连接 WorkBuddy")
}

enum CreditError: LocalizedError {
    case login, malformed, server(Int), network, accountChanged
    var errorDescription: String? {
        switch self {
        case .login: return "请登录 WorkBuddy 官网后刷新"
        case .malformed: return "积分接口格式发生变化，请稍后重试"
        case .server(let code): return "查询未成功（\(code)），请稍后重试"
        case .network: return "暂时无法连接 WorkBuddy"
        case .accountChanged: return "账号已切换，正在重新读取积分"
        }
    }
}

enum CreditParser {
    static func number(_ value: Any?) throws -> Double {
        let n: Double?
        if let s = value as? String { n = Double(s) }
        else if let v = value as? NSNumber, CFGetTypeID(v) != CFBooleanGetTypeID() { n = v.doubleValue }
        else { n = nil }
        guard let n, n.isFinite, n >= 0 else { throw CreditError.malformed }
        return n
    }
    static func body(_ object: [String: Any]) throws -> [String: Any] {
        guard let code = object["code"] as? Int else { throw CreditError.malformed }
        if code == 401 || code == 403 { throw CreditError.login }
        guard code == 0 else { throw CreditError.server(code) }
        guard let data = object["data"] as? [String: Any] else { throw CreditError.malformed }
        return data
    }
    static func personal(_ object: [String: Any]) throws -> CreditSnapshot {
        let data = try body(object)
        guard let rows = data["Packages"] as? [[String: Any]] else { throw CreditError.malformed }
        let packages = try rows.enumerated().map { index, row in
            let code = row["PackageCode"] as? String ?? ""
            return CreditPackage(id: "\(code)-\(index)", name: row["PackageName"] as? String ?? code,
                remaining: try number(row["CycleRemainCapacity"]), total: try number(row["CycleTotalCapacity"]),
                used: try number(row["CycleUsedCapacity"]))
        }
        let name = data["SubscriptionPackageName"] as? String
        return CreditSnapshot(remaining: packages.reduce(0) { $0 + $1.remaining }, total: packages.reduce(0) { $0 + $1.total },
            used: packages.reduce(0) { $0 + $1.used }, plan: name?.isEmpty == false ? name! : "个人版", packages: packages, updatedAt: Date())
    }
    static func enterprise(_ object: [String: Any]) throws -> CreditSnapshot {
        let outer = try body(object)
        let data = outer["data"] as? [String: Any] ?? outer
        let rawLimit = data["limitNum"] ?? data["limit_num"]
        let unlimited = (rawLimit as? NSNumber)?.doubleValue == -1 || (rawLimit as? String) == "-1"
        let total = unlimited ? 0 : try number(rawLimit)
        let used = try number(data["credit"] ?? data["used_num"])
        return CreditSnapshot(remaining: max(0, total - used), total: total, used: used, plan: "企业版", packages: [], updatedAt: Date(), unlimited: unlimited)
    }
}

import CoreFoundation

enum CreditFormat {
    static func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }
    static func remaining(_ snapshot: CreditSnapshot?) -> String {
        guard let snapshot else { return "—" }
        return snapshot.unlimited ? "∞" : number(snapshot.remaining)
    }
}

enum PayloadCache {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WorkBuddyCreditWidget/snapshot.json")
    }
    static func read() -> CreditPayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CreditPayload.self, from: data)
    }
    static func save(_ payload: CreditPayload) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(payload).write(to: url, options: .atomic)
    }
}
