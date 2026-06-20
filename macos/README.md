# os-bar (macOS)

Native macOS menu bar system monitor. Built with SwiftUI `MenuBarExtra` and a Go metrics daemon.

## Requirements

- macOS 13.0+
- Swift 5.9+ (Xcode 15+ or standalone toolchain)
- Go 1.25+ (for daemon build and tests)

## Development

```sh
# Build Go daemon + Swift app, run with bundled daemon path
./script/dev.sh

# Or manually
cd go-pkgs/cmd/os-bar && go build -o ../../.build/os-bar-daemon .
swift build
OS_BAR_CLI=.build/os-bar-daemon swift run os-bar
```

## Distribution

```sh
./script/bundle.sh
```

Produces `os-bar.dmg` with both `os-bar` (Swift UI) and `os-bar-daemon` (Go backend) in `Contents/MacOS/`. Open, drag to `/Applications`, first launch via right-click → Open.

## Testing

```sh
# Go daemon doctests (primary automated suite)
cd go-pkgs/cmd/os-bar
doctest test ../../server/tests

# Legacy Swift bridge tests (deprecated — use server/tests above)
doctest test ./tests/menubar-monitor
```

## Architecture

Go owns metrics collection and the HTTP daemon; Swift is a thin client.

```
┌─────────────────────────────┐
│  os-bar (Swift MenuBarExtra)│
│  SystemMonitor polls HTTP   │
│  spawns os-bar-daemon serve │
└──────────────┬──────────────┘
               │ http://127.0.0.1:38270
┌──────────────▼──────────────┐
│  os-bar-daemon (Go)         │
│  monitor/  CPU & MEM %      │
│  server/   HTTP API         │
└─────────────────────────────┘
```

| Component | Path | Role |
|-----------|------|------|
| `os-bar/os_barApp.swift` | Swift | Menu bar UI, metric picker, auto-start toggle |
| `os-bar/DaemonClient.swift` | Swift | HTTP client → `127.0.0.1:38270` |
| `os-bar/SystemMonitor.swift` | Swift | Polls daemon every 10s; spawns daemon if unhealthy |
| `go-pkgs/monitor/` | Go | Real (gopsutil) and mock metrics providers |
| `go-pkgs/server/` | Go | HTTP daemon, singleton, `/api/metrics` |
| `go-pkgs/cmd/os-bar/` | Go | `serve` and `metrics` CLI; builds as `os-bar-daemon` |

Daemon binary resolution: `OS_BAR_CLI` env → bundled `os-bar-daemon` → `/usr/local/bin/os-bar-daemon`.

## Menu Bar

Shows one metric at a time (default: CPU). Switch via dropdown picker — choice persists in UserDefaults.

```
 [􀫥 38%]          ← bar label (single metric)
 ─────────────────  ← click to expand
 CPU: 38%
 Memory: 72%

 Show in menu bar: ○ CPU  ● Memory
 ─────────────────
 Quit os-bar
```