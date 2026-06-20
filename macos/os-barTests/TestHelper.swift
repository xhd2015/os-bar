import Foundation

// Deprecated: metrics backend moved to Go daemon (go-pkgs/server/tests).
// Retained for reference; no longer used by automated tests.

// MARK: - JSON Request/Response Models

struct Request: Codable {
    let action: String
}

struct Response: Codable {
    let cpu_percent: Double
    let mem_percent: Double
}

// MARK: - Mock Provider

/// Returns predetermined values to allow deterministic testing.
/// - Tick 0 (initial): CPU = 45.2%, MEM = 72.8%
/// - Tick 1:          CPU = 52.3%, MEM = 68.1%
/// - Tick 2+:         CPU = 38.7%, MEM = 75.4%
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

// MARK: - Main (top-level entry point, no @main needed)

func runHelper() -> Never {
    let provider = MockSystemInfoProvider()

    // Read a single JSON line from stdin
    guard let input = readLine() else {
        fputs("ERROR: no input provided on stdin\n", stderr)
        exit(1)
    }

    guard let jsonData = input.data(using: .utf8),
          let request = try? JSONDecoder().decode(Request.self, from: jsonData)
    else {
        fputs("ERROR: invalid JSON input\n", stderr)
        exit(1)
    }

    // Dispatch on action
    switch request.action {
    case "fetch":
        // Return current snapshot values (tick 0)
        break

    case "wait_tick":
        // Advance the mock to simulate a timer tick, then snapshot
        provider.advanceTick()

    default:
        fputs("ERROR: unknown action '\(request.action)'\n", stderr)
        exit(1)
    }

    let response = Response(
        cpu_percent: provider.cpuPercent,
        mem_percent: provider.memPercent
    )

    guard let outputData = try? JSONEncoder().encode(response),
          let output = String(data: outputData, encoding: .utf8)
    else {
        fputs("ERROR: failed to encode response\n", stderr)
        exit(1)
    }

    print(output)
    fflush(stdout)
    exit(0)
}

runHelper()
