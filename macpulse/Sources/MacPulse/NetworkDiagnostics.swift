import Foundation
import Network
import Darwin

struct NetworkState {
    let state: String
    let interface: String
    let isExpensive: Bool
    let isConstrained: Bool
    let supportsIPv4: Bool
    let supportsIPv6: Bool

    static let unknown = NetworkState(state: "Checking…", interface: "Unknown",
                                      isExpensive: false, isConstrained: false,
                                      supportsIPv4: false, supportsIPv6: false)
}

/// Passive macOS route availability monitor, not a VPN server or packet inspection.
final class NetworkPathObserver {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "macpulse.network.path")
    var onUpdate: ((NetworkState) -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let kind: String
            if path.usesInterfaceType(.wifi) { kind = "Wi-Fi" }
            else if path.usesInterfaceType(.wiredEthernet) { kind = "Ethernet" }
            else if path.usesInterfaceType(.cellular) { kind = "Cellular" }
            else { kind = "Other / VPN" }
            let summary = NetworkState(
                state: path.status == .satisfied ? "Connected" :
                    (path.status == .requiresConnection ? "Connection required" : "No route available"),
                interface: kind,
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained,
                supportsIPv4: path.supportsIPv4,
                supportsIPv6: path.supportsIPv6
            )
            self?.onUpdate?(summary)
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}

struct DNSLookup: Identifiable {
    let host: String
    let addresses: [String]
    let elapsedMs: Int
    let error: String?
    let timestamp: Date = .now
    var id: Date { timestamp }
}

/// User-initiated resolution via getaddrinfo; never uses shell injection or
/// uploads domain names to MacPulse-controlled servers.
enum DNSDiagnostics {
    static func resolve(_ rawHost: String) -> DNSLookup {
        let host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty, host.utf8.count <= 253,
              host.range(of: #"^[a-z0-9][a-z0-9.-]*$"#, options: .regularExpression) != nil,
              !host.hasSuffix("."), !host.contains("..") else {
            return DNSLookup(host: host, addresses: [], elapsedMs: 0,
                             error: "Enter a hostname such as example.com (letters, digits, dots, hyphens).")
        }
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_ADDRCONFIG
        var result: UnsafeMutablePointer<addrinfo>?
        let started = Date()
        let status = getaddrinfo(host, nil, &hints, &result)
        let millis = Int(Date().timeIntervalSince(started) * 1000)
        guard status == 0, let first = result else {
            return DNSLookup(host: host, addresses: [], elapsedMs: millis,
                             error: String(cString: gai_strerror(status)))
        }
        defer { freeaddrinfo(first) }
        var addresses = Set<String>()
        var pointer: UnsafeMutablePointer<addrinfo>? = first
        while let node = pointer {
            let next = node.pointee.ai_next
            if let address = node.pointee.ai_addr {
                var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let error = getnameinfo(address, node.pointee.ai_addrlen, &name,
                                        socklen_t(name.count), nil, 0, NI_NUMERICHOST)
                if error == 0 { addresses.insert(String(cString: name)) }
            }
            pointer = next
        }
        return DNSLookup(host: host, addresses: addresses.sorted(), elapsedMs: millis, error: nil)
    }
}
