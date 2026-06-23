# Scenario

**Feature**: JSONL log storage, migration, API parity, Finder menu labels, Logs viewer

```
# storage: isolated serve + HTTP notify/logs → notify-logs.jsonl on disk
doctest Run(req) -> build agent-sessions -> serve --state-dir --port -> POST/GET

# menu + viewer: Swift test helper mirrors OpenLogsMenuState + LogsViewModel
doctest -> open_logs_menu_state | logs_viewer_menu_state | logs_viewer_* -> TestHelper.swift
```

## Preconditions

- The `agent-sessions` CLI exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")`.
- On-disk log file is `{stateDir}/notify-logs.jsonl` (legacy `notify-logs.json` migrated on load).
- `GET /api/logs` returns a JSON **array** (not JSONL text).
- **Isolation (mandatory):** Every test uses `stateDir` under `t.TempDir()`; never reads/writes real `~/.os-bar/`.
- Tests use ephemeral ports; never bind production port `38271`.
- Swift test helper is built from `os-bar-agent-sessionsTests/TestHelper.swift` for menu/viewer leaves.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Dispatch by `req.Action` in root `Run(t, req)`:
   - `http_sequence` — build CLI, start `serve`, run `req.HTTPSteps`
   - `open_logs_menu_state` — Swift helper: Finder menu label + enabled (`OpenLogsMenuState`)
   - `logs_viewer_menu_state` — Swift helper: Logs viewer menu label + enabled
   - `logs_viewer_format_entry` — Swift helper: format one log row for display
   - `logs_viewer_poll_detects_new` — Swift helper: simulate two poll cycles
2. Leaf `Setup` configures action-specific parameters and optional disk seeds.
3. Leaf `Assert` validates on-disk JSONL, HTTP body, menu state, or viewer output.
4. Return `(*Response, nil)` on success.

## Context

- Log-only notify: POST `/api/notify` without `source=notify`.
- JSONL format: one `NotifyLogEntry` per line, newline-terminated; no wrapping `[` `]`.
- Cap: 200 entries; compact rewrites tail when over cap.
- Finder menu: **Show Logs in Finder** (disabled with `(daemon unreachable)` on error).
- Logs viewer menu: **Logs** stays enabled; window shows error banner when daemon is down.
- Viewer poll interval: 2 seconds (not wall-clock asserted in unit tests).

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("logs-jsonl: root setup — Run() dispatches by req.Action")
	return nil
}
```