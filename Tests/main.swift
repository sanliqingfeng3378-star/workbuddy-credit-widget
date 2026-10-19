import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
func rejects(_ value: Any?) {
    do { _ = try CreditParser.number(value); fatalError("Accepted invalid number") } catch {}
}
let source: [String: Any] = ["code": 0, "data": ["SubscriptionPackageName": "标准版", "Packages": [
    ["PackageCode": "base", "CycleTotalCapacity": "2000", "CycleRemainCapacity": "1177.5", "CycleUsedCapacity": "822.5"],
    ["PackageCode": "gift", "CycleTotalCapacity": 2000, "CycleRemainCapacity": 2000, "CycleUsedCapacity": 0]
]]]
let snapshot = try CreditParser.personal(source)
check(snapshot.remaining == 3177.5, "Decimal credits must be preserved")
check(snapshot.total == 4000 && snapshot.used == 822.5, "Both package groups must be included")
let zero = try CreditParser.personal(["code": 0, "data": ["Packages": []]])
check(zero.remaining == 0 && zero.fraction == 0, "Valid empty account")
rejects(nil); rejects(true); rejects("NaN"); rejects(-1); rejects(Double.infinity)
do { _ = try CreditParser.personal(["code": 0, "data": [:]]); fatalError("Missing packages must not become zero") } catch {}
do { _ = try CreditParser.personal(["code": 401]); fatalError("Unauthorized response must fail") } catch CreditError.login {} catch { fatalError("Wrong error") }
let enterprise = try CreditParser.enterprise(["code": 0, "data": ["limitNum": 100, "credit": 110]])
check(enterprise.remaining == 0, "Overage must clamp remaining to zero")
let unlimited = try CreditParser.enterprise(["code": 0, "data": ["limit_num": -1, "used_num": 19.5]])
check(unlimited.unlimited && unlimited.fraction == 1, "Unlimited plan")
let payload = CreditPayload(snapshot: snapshot, message: "暂时离线")
let roundTrip = try JSONDecoder().decode(CreditPayload.self, from: JSONEncoder().encode(payload))
check(roundTrip.snapshot?.remaining == 3177.5 && roundTrip.message == payload.message, "Cache preserves decimals and errors")
print("PASS: package totals, decimals, invalid data, zero balance, authentication, enterprise, unlimited, cache")

// The local bridge only serves the native widget's exact loopback endpoint.
assert(CreditBridge.responseStatus(headers: "GET /v1/credits HTTP/1.1\r\nHost: 127.0.0.1:38348") == "200 OK")
assert(CreditBridge.responseStatus(headers: "GET /v1/credits HTTP/1.1\r\nHost: evil.example") == "403 Forbidden")
assert(CreditBridge.responseStatus(headers: "GET /v1/credits HTTP/1.1\r\nHost: 127.0.0.1:38348\r\nOrigin: https://example.com") == "403 Forbidden")
assert(CreditBridge.responseStatus(headers: "POST /v1/credits HTTP/1.1\r\nHost: 127.0.0.1:38348") == "404 Not Found")
assert(CreditBridge.responseStatus(headers: "GET /v1/credits HTTP/1.1\r\nHost: 127.0.0.1:38348\r\nHost: evil.example") == "403 Forbidden")
print("Bridge request validation passed")
