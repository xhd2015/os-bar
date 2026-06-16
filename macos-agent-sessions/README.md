# os-bar-agent-sessions (macOS)

Native macOS menu bar app that receives coding-session notifications from
Cursor, OpenCode, pi-coding-agent, and other tools via a local HTTP API.

Built with SwiftUI `MenuBarExtra` + `Network.framework`.

## Requirements

- macOS 13.0+
- Swift 5.9+ (Xcode 15+ or standalone toolchain)

## Quick Start

```sh
# Build & run
./script/dev.sh

# Or manually
swift build
swift run os-bar-agent-sessions
```

## API

The app listens on `localhost:38271`. Notify it from any tool:

```sh
curl -X POST http://localhost:38271/api/notify \
  -H "Content-Type: application/json" \
  -d '{"type":"session.finished","dir":"/path/to/project"}'
```

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/notify` | `POST` | Register a session event. `type` is accepted but ignored; only `dir` matters |

## Distribution

```sh
./script/bundle.sh
```

Produces `os-bar-agent-sessions.dmg`. Open, drag to `/Applications`, first launch via right-click → Open.

## Testing

```sh
# Doc-style tests (Go doctest framework)
doctest test ./tests/session-notifications

# Vet the test tree
doctest vet ./tests/session-notifications
```

## Architecture

| File | Purpose |
|------|---------|
| `os-bar-agent-sessions/AgentSessionApp.swift` | `@main` MenuBarExtra app, bar label, dropdown menu |
| `os-bar-agent-sessions/SessionEvent.swift` | Codable event model — id (UUID), dir, timestamp |
| `os-bar-agent-sessions/SessionStore.swift` | `ObservableObject` — add/dedup/prune (7d)/cap (20)/sort/relative-time |
| `os-bar-agent-sessions/SessionServer.swift` | `NWListener` HTTP server on `:38271`, port-conflict NSAlert |
| `os-bar-agent-sessionsTests/TestHelper.swift` | Self-contained test helper for doctest bridge |

## Menu Bar

Shows a bell icon + event count. Click to expand the dropdown.

```
 [􀋙 3]                    ← bar label (bell + count)
 ─────────────────────────  ← click to expand
 my-project — 2m ago        ← click opens `code /path`
 another — 7m ago
 utils — 1h ago
 ─────────────────────────
 Quit
```

### Storage Rules

- **7-day window**: events older than 7 days are pruned on load
- **Cap**: maximum 20 events; oldest evicted when cap is exceeded
- **Dedup by dir**: posting the same `dir` bumps its timestamp to now (no duplicate)
- **Persistence**: events saved to `UserDefaults` across restarts
- **Relative time**: computed on dropdown open, not live-updating

### Port Conflict

If `:38271` is already in use, a dialog appears showing the occupying PID with two options:

- **Kill & Continue** — sends SIGTERM, retries bind
- **Exit** — quits the app
