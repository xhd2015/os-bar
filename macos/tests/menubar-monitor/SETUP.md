# Scenario

**Feature**: menu bar `SystemMonitor` CPU/MEM metrics via Swift test helper (deprecated — automated leaves moved to `go-pkgs/server/tests/`)

## Preconditions
- The macOS project exists at `macos/os-bar.xcodeproj/` with the `os-bar` target.
- A `SystemMonitor` class is implemented in `macos/os-bar/SystemMonitor.swift`, exposed as `@Observable` with properties `cpuPercent: Double` and `memPercent: Double`.
- `SystemMonitor` accepts a configurable host-info fetcher so tests can inject mock data (no dependency on live OS metrics).
- A Swift test helper executable exists at `macos/.build/test-helper` that accepts a JSON `Request` on stdin (single line) and outputs a JSON `Response` on stdout. The helper creates a `SystemMonitor` instance with mock data, invokes the requested action, and prints the snapshot.

## Steps
1. Build the Swift test helper if not already built: `swiftc -o macos/.build/test-helper macos/os-barTests/TestHelper.swift`
2. Serialize `req` (Go `Request` struct) to JSON: `{"action": "<Action>"}`.
3. Pipe the JSON into the test helper via stdin.
4. Read the test helper's stdout and parse it as a JSON `Response` struct.
5. Return `(*Response, nil)` on success, or `(nil, error)` on failure.

## Context
- Action `"fetch"` means: take an immediate snapshot of CPU and MEM percentages.
- Action `"wait_tick"` means: wait for the next timer tick (or fast-forward the mock timer), then take a snapshot.
- The mock fetcher returns predetermined values: e.g., CPU = 45.2%, MEM = 72.8% on first fetch, and different values after each tick.
- Both `cpuPercent` and `memPercent` are `Double` values in the range `[0.0, 100.0]`.
