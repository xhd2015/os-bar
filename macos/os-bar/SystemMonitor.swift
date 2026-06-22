import Foundation

final class SystemMonitor: ObservableObject {
    @Published var cpuPercent: Double = 0
    @Published var cpuCores: Int = 0
    @Published var memPercent: Double = 0
    @Published var memTotalBytes: UInt64 = 0
    @Published var memUsedBytes: UInt64 = 0
    @Published var swapTotalBytes: UInt64 = 0
    @Published var swapUsedBytes: UInt64 = 0

    var cpuDisplay: String {
        if cpuCores <= 0 {
            return "\(Int(cpuPercent.rounded()))%"
        }
        return "\(Int(cpuPercent.rounded()))% (\(cpuCores) cores)"
    }

    var memDisplay: String {
        Self.formatMemDisplay(total: memTotalBytes, used: memUsedBytes)
    }

    var swapDisplay: String {
        Self.formatSwapDisplay(total: swapTotalBytes, used: swapUsedBytes)
    }

    private static func formatMemDisplay(total: UInt64, used: UInt64) -> String {
        if total == 0 { return "0% (0B/0B)" }
        let percent = (used * 100 + total / 2) / total
        return "\(percent)% (\(formatBytes(used))/\(formatBytes(total)))"
    }

    private static func formatSwapDisplay(total: UInt64, used: UInt64) -> String {
        if total == 0 { return "0% (0B/0B)" }
        let percent = (used * 100 + total / 2) / total
        return "\(percent)% (\(formatBytes(used))/\(formatBytes(total)))"
    }

    private static func formatBytes(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0B" }
        let gib: UInt64 = 1024 * 1024 * 1024
        let mib: UInt64 = 1024 * 1024
        if bytes >= gib {
            return "\(bytes / gib)GB"
        }
        if bytes >= mib {
            return "\(bytes / mib)MB"
        }
        return "\(bytes)B"
    }

    private let client: DaemonClient
    private var timer: Timer?
    private var daemonProcess: Process?

    init(client: DaemonClient = .shared) {
        self.client = client
        Task { @MainActor in
            await ensureDaemonRunning()
            await fetchMetrics()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchMetrics()
            }
        }
    }

    func start() {
        // Timer already started in init; no-op for compatibility
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func fetchMetrics() async {
        do {
            let snapshot = try await client.metrics()
            cpuPercent = snapshot.cpuPercent
            cpuCores = snapshot.cpuCores
            memPercent = snapshot.memPercent
            memTotalBytes = snapshot.memTotalBytes
            memUsedBytes = snapshot.memUsedBytes
            swapTotalBytes = snapshot.swapTotalBytes
            swapUsedBytes = snapshot.swapUsedBytes
        } catch {
            print("Failed to fetch metrics: \(error)")
        }
    }

    @MainActor
    private func ensureDaemonRunning() async {
        if (try? await client.health()) == true {
            return
        }
        spawnDaemon()
        for _ in 0..<50 {
            if (try? await client.health()) == true {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        print("Warning: daemon health check failed after spawn")
    }

    private func spawnDaemon() {
        let binary = daemonBinaryPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["serve"]
        process.environment = ProcessInfo.processInfo.environment
        do {
            try process.run()
            daemonProcess = process
        } catch {
            print("Failed to spawn daemon at \(binary): \(error)")
        }
    }

    private func daemonBinaryPath() -> String {
        if let cli = ProcessInfo.processInfo.environment["OS_BAR_CLI"], !cli.isEmpty {
            return cli
        }
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/os-bar-daemon")
            .path
        if FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        return "/usr/local/bin/os-bar-daemon"
    }
}