import Foundation

// MARK: - JSON Request/Response Models

struct Request: Codable {
    let action: String
    let spawned_pid: Int?
    let spawned_running: Bool?
    let pid_file_contents: String?
    let state_dir_env_value: String?
    let home: String?
}

struct Response: Codable {
    var cpu_percent: Double = 0
    var mem_percent: Double = 0
    var error: String = ""
    var quit_target_kind: String = ""
    var quit_target_pid: Int = 0
    var state_dir: String = ""
}

// MARK: - Mock Provider (legacy menubar-monitor)

class MockSystemInfoProvider {
    private(set) var tick = 0

    var cpuPercent: Double {
        switch tick {
        case 0: return 45.2
        case 1: return 52.3
        default: return 38.7
        }
    }

    var memPercent: Double {
        switch tick {
        case 0: return 72.8
        case 1: return 68.1
        default: return 75.4
        }
    }

    func advanceTick() {
        tick += 1
    }
}

// MARK: - Daemon shutdown mirror

struct DaemonShutdownConfig: Equatable {
    let stateDirEnvKey: String
    let defaultRelativeStateDir: String
}

enum TestDaemonShutdown {
    static let osBar = DaemonShutdownConfig(
        stateDirEnvKey: "OS_BAR_STATE_DIR",
        defaultRelativeStateDir: ".os-bar/os-bar"
    )

    enum Target: Equatable {
        case none
        case spawned(pid: Int32)
        case pidFile(pid: Int32)
    }

    static func resolveStateDir(
        config: DaemonShutdownConfig,
        env: [String: String],
        home: String
    ) -> String {
        if let stateDir = env[config.stateDirEnvKey], !stateDir.isEmpty {
            return stateDir
        }
        return (home as NSString).appendingPathComponent(config.defaultRelativeStateDir)
    }

    static func pidFilePath(stateDir: String) -> String {
        (stateDir as NSString).appendingPathComponent("daemon.pid")
    }

    static func parsePID(_ contents: String) -> Int32? {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = Int32(trimmed), pid > 0 else {
            return nil
        }
        return pid
    }

    static func quitTarget(
        spawnedPID: Int32?,
        spawnedRunning: Bool,
        pidFileContents: String?
    ) -> Target {
        if let spawnedPID, spawnedRunning {
            return .spawned(pid: spawnedPID)
        }
        if let pidFileContents, let pid = parsePID(pidFileContents) {
            return .pidFile(pid: pid)
        }
        return .none
    }

    static func encodeTarget(_ target: Target) -> (kind: String, pid: Int) {
        switch target {
        case .none:
            return ("none", 0)
        case .spawned(let pid):
            return ("spawned", Int(pid))
        case .pidFile(let pid):
            return ("pid_file", Int(pid))
        }
    }
}

// MARK: - Main

func runHelper() -> Never {
    let provider = MockSystemInfoProvider()

    guard let input = readLine() else {
        fputs("{\"error\":\"no input provided\"}\n", stderr)
        exit(1)
    }

    guard let jsonData = input.data(using: .utf8),
          let request = try? JSONDecoder().decode(Request.self, from: jsonData)
    else {
        fputs("{\"error\":\"invalid JSON input\"}\n", stderr)
        exit(1)
    }

    var response = Response()

    switch request.action {
    case "fetch":
        break

    case "wait_tick":
        provider.advanceTick()

    case "daemon_quit_plan":
        let spawnedPID = request.spawned_pid.map { Int32($0) }
        let spawnedRunning = request.spawned_running ?? false
        let target = TestDaemonShutdown.quitTarget(
            spawnedPID: spawnedPID,
            spawnedRunning: spawnedRunning,
            pidFileContents: request.pid_file_contents
        )
        let encoded = TestDaemonShutdown.encodeTarget(target)
        response.quit_target_kind = encoded.kind
        response.quit_target_pid = encoded.pid

        var env = ProcessInfo.processInfo.environment
        if let override = request.state_dir_env_value {
            env[TestDaemonShutdown.osBar.stateDirEnvKey] = override
        }
        let home = request.home ?? "/Users/tester"
        response.state_dir = TestDaemonShutdown.resolveStateDir(
            config: TestDaemonShutdown.osBar,
            env: env,
            home: home
        )

    default:
        response.error = "unknown action: \(request.action)"
    }

    response.cpu_percent = provider.cpuPercent
    response.mem_percent = provider.memPercent

    guard let outputData = try? JSONEncoder().encode(response),
          let output = String(data: outputData, encoding: .utf8)
    else {
        fputs("{\"error\":\"failed to encode response\"}\n", stderr)
        exit(1)
    }

    print(output)
    fflush(stdout)
    exit(0)
}

runHelper()