# os-bar (macOS)

Native macOS menu bar system monitor. Built with SwiftUI `MenuBarExtra`.

## Requirements

- macOS 13.0+
- Swift 5.9+ (Xcode 15+ or standalone toolchain)

## Development

```sh
# Build & run
./script/dev.sh

# Or manually
swift build
swift run os-bar
```

## Distribution

```sh
./script/bundle.sh
```

Produces `os-bar.dmg`. Open, drag to `/Applications`, first launch via right-click → Open.

## Testing

```sh
# Doc-style tests (Go doctest framework)
doctest test ./tests/menubar-monitor

# Swift tests (project-level)
swift test
```

## Architecture

| File | Purpose |
|------|---------|
| `os-bar/os_barApp.swift` | `@main` MenuBarExtra app, bar label, dropdown menu |
| `os-bar/SystemMonitor.swift` | `ObservableObject` — fetches CPU (host_processor_info) and MEM (host_statistics64 + sysctl) every 10s |
| `os-barTests/TestHelper.swift` | Mock provider for doctest bridge |

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
