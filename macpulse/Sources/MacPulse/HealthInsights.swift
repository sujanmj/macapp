import Foundation

enum InsightLevel: String {
    case attention = "Needs review"
    case information = "Informational"
    case normal = "Looks normal"

    var icon: String {
        switch self {
        case .attention: return "exclamationmark.triangle.fill"
        case .information: return "info.circle.fill"
        case .normal: return "checkmark.circle.fill"
        }
    }
}

struct HealthInsight: Identifiable {
    let id: String
    let level: InsightLevel
    let title: String
    let explanation: String
    let recommendedAction: String
    let page: PulsePage?
}

/// Simple deterministic guidance, never a claim of malware detection, medical
/// battery diagnosis, or a quantitative "Mac health score".
enum HealthInsights {
    static func evaluate(
        snapshot: SystemSnapshot,
        metrics: LiveMetrics,
        network: NetworkState,
        security: [SecurityFinding],
        developer: [DeveloperFolderReport]
    ) -> [HealthInsight] {
        var insights: [HealthInsight] = []

        if snapshot.totalDisk > 0 {
            let available = Double(snapshot.freeDisk) / Double(snapshot.totalDisk)
            if available < 0.10 || snapshot.freeDisk < 15 * 1_073_741_824 {
                insights.append(HealthInsight(
                    id: "disk", level: .attention, title: "Disk space is running low",
                    explanation: "Your disk reports \(SystemSnapshot.bytes(snapshot.freeDisk)) free. Low free space can affect app updates and temporary files.",
                    recommendedAction: "Inspect large files in Storage Analyzer; only trash files you recognize.",
                    page: .storage
                ))
            } else {
                insights.append(HealthInsight(
                    id: "disk", level: .normal, title: "Disk space appears sufficient",
                    explanation: "\(SystemSnapshot.bytes(snapshot.freeDisk)) is available on the measured volume.",
                    recommendedAction: "Use Storage Analyzer whenever you want a closer look.",
                    page: .storage
                ))
            }
        }

        if metrics.thermalState == "High" || metrics.thermalState == "Critical" {
            insights.append(HealthInsight(
                id: "thermal", level: .attention, title: "macOS reports high thermal pressure",
                explanation: "The system thermal state is \(metrics.thermalState). This is a power-management signal, not a physical temperature reading.",
                recommendedAction: "Check running workloads, ventilation and Activity Monitor before changing anything.",
                page: .performance
            ))
        } else if metrics.thermalState == "Normal" {
            insights.append(HealthInsight(
                id: "thermal", level: .normal, title: "Thermal state is normal",
                explanation: "macOS currently reports nominal thermal conditions.",
                recommendedAction: "Watch the Performance view during sustained workloads.",
                page: .performance
            ))
        }

        if let cpu = metrics.cpuPercent, cpu >= 90 {
            insights.append(HealthInsight(
                id: "cpu", level: .information, title: "High CPU activity in the latest sample",
                explanation: "Measured CPU utilization is approximately \(Int(cpu))%. A single busy interval is not necessarily a fault.",
                recommendedAction: "Watch the CPU history and inspect Activity Monitor if usage stays elevated.",
                page: .performance
            ))
        }

        if let charge = metrics.batteryPercent,
           charge <= 15, metrics.batteryState == "Discharging" {
            insights.append(HealthInsight(
                id: "battery", level: .attention, title: "Battery is getting low",
                explanation: "The current charge is approximately \(charge)% and macOS reports discharging.",
                recommendedAction: "Connect power when convenient or reduce demanding workloads.",
                page: .performance
            ))
        }

        if network.state == "No route available" {
            insights.append(HealthInsight(
                id: "network", level: .information, title: "No active network route detected",
                explanation: "Network.framework currently reports no satisfied route. This does not prove a particular provider or VPN is down.",
                recommendedAction: "Check your Wi-Fi, network configuration and VPN settings.",
                page: .vpn
            ))
        }

        let issues = security.filter { $0.status == .attention }
        if !issues.isEmpty {
            insights.append(HealthInsight(
                id: "security", level: .attention, title: "\(issues.count) macOS setting(s) need review",
                explanation: issues.prefix(3).map(\.title).joined(separator: ", ") +
                    ". These are configuration observations, not proof of malware.",
                recommendedAction: "Review the findings and verify settings in System Settings.",
                page: .security
            ))
        } else if security.isEmpty {
            insights.append(HealthInsight(
                id: "security", level: .information, title: "Security status hasn't been checked",
                explanation: "No security-check results are available for this session.",
                recommendedAction: "Run the Security Center checks to get a clearer picture.",
                page: .security
            ))
        } else {
            insights.append(HealthInsight(
                id: "security", level: .information, title: "No reviewed security-setting alerts",
                explanation: "The latest checks found no settings explicitly flagged for review. Unavailable checks remain unknown.",
                recommendedAction: "This is not an antivirus scan or a guarantee of security.",
                page: .security
            ))
        }

        let largeDev = developer.filter {
            $0.exists && $0.measuredBytes > 10 * 1_073_741_824
        }
        if let candidate = largeDev.max(by: { $0.measuredBytes < $1.measuredBytes }) {
            insights.append(HealthInsight(
                id: "developer", level: .information,
                title: "A developer folder is using significant storage",
                explanation: "\(candidate.name) contains at least \(SystemSnapshot.bytes(candidate.measuredBytes)) of measured files\(candidate.partial ? " (partial scan)" : "").",
                recommendedAction: "Review the folder before removing caches; avoid deleting active builds or Xcode Archives.",
                page: .developer
            ))
        }

        if snapshot.memoryRatio >= 0.85 {
            insights.append(HealthInsight(
                id: "memory", level: .information, title: "Most physical RAM is allocated",
                explanation: "macOS often uses spare RAM for useful caches. Allocation alone does not indicate high memory pressure.",
                recommendedAction: "If the Mac actually feels slow, check Activity Monitor's Memory Pressure graph.",
                page: .memory
            ))
        }
        if insights.isEmpty {
            insights.append(HealthInsight(
                id: "empty", level: .information, title: "Collecting system measurements",
                explanation: "MacPulse needs available system signals to generate local recommendations.",
                recommendedAction: "Refresh the dashboard and run optional diagnostics.",
                page: .dashboard
            ))
        }
        return insights.sorted { priority($0.level) < priority($1.level) }
    }

    private static func priority(_ level: InsightLevel) -> Int {
        switch level {
        case .attention: return 0
        case .information: return 1
        case .normal: return 2
        }
    }
}
