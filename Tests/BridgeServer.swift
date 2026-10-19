import Foundation

@main
struct BridgeServer {
    static func main() {
        let bridge = CreditBridge(port: UInt16(CommandLine.arguments[1])!)
        bridge.publish(CreditPayload(snapshot: .preview, message: "Synthetic integration fixture"))
        bridge.start()
        withExtendedLifetime(bridge) { dispatchMain() }
    }
}
