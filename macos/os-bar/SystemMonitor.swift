import Foundation

final class SystemMonitor: ObservableObject {
    @Published var cpuPercent: Double = 0
    @Published var memPercent: Double = 0

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
            memPercent = snapshot.memPercent
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