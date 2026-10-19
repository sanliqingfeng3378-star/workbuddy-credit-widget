import Foundation
import Network

/// A credential-free snapshot transport for the sandboxed WidgetKit extension.
/// All mutable state is confined to queue; only IPv4 loopback is accepted.
final class CreditBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "workbuddycredits.snapshot-server")
    private var listener: NWListener?
    private var snapshot = Data()
    private let port: UInt16

    init(port: UInt16 = 38348) { self.port = port }

    func start() {
        queue.async { [self] in
            guard listener == nil, let endpointPort = NWEndpoint.Port(rawValue: port) else { return }
            do {
                let config = NWParameters.tcp
                config.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: endpointPort)
                let service = try NWListener(using: config)
                service.newConnectionHandler = { [weak self] client in
                    guard let self else { client.cancel(); return }
                    client.start(queue: self.queue)
                    self.queue.asyncAfter(deadline: .now() + 3) { client.cancel() }
                    self.read(client, accumulated: Data())
                }
                service.stateUpdateHandler = { [weak self] state in
                    if case .failed = state {
                        self?.listener?.cancel()
                        self?.listener = nil
                        NSLog("WorkBuddy snapshot service unavailable; check for another running copy")
                    }
                }
                listener = service
                service.start(queue: queue)
            } catch {
                NSLog("WorkBuddy snapshot service could not start")
            }
        }
    }

    func publish(_ payload: CreditPayload) {
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        queue.async { self.snapshot = encoded }
    }

    private func read(_ client: NWConnection, accumulated: Data) {
        client.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] chunk, _, ended, error in
            guard let self else { client.cancel(); return }
            var request = accumulated
            if let chunk { request.append(chunk) }
            guard request.count <= 8192 else { self.respond(client, status: "431 Request Header Fields Too Large"); return }
            if let boundary = request.range(of: Data("\r\n\r\n".utf8)) {
                let headers = String(decoding: request[..<boundary.lowerBound], as: UTF8.self)
                let status = Self.responseStatus(headers: headers, port: self.port)
                self.respond(client, status: status, body: status == "200 OK" ? self.snapshot : Data())
            } else if ended || error != nil {
                client.cancel()
            } else {
                self.read(client, accumulated: request)
            }
        }
    }

    static func responseStatus(headers: String, port: UInt16 = 38348) -> String {
        let lines = headers.components(separatedBy: "\r\n")
        guard lines.first == "GET /v1/credits HTTP/1.1" else { return "404 Not Found" }
        var hosts: [String] = []
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return "400 Bad Request" }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            // The native widget sends no Origin. Reject browser-originated requests.
            if key == "origin" { return "403 Forbidden" }
            if key == "host" { hosts.append(value) }
        }
        guard hosts == ["127.0.0.1:\(port)"] else { return "403 Forbidden" }
        return "200 OK"
    }

    private func respond(_ client: NWConnection, status: String, body: Data = Data()) {
        let headers = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        client.send(content: Data(headers.utf8) + body, completion: .contentProcessed { _ in client.cancel() })
    }
}
