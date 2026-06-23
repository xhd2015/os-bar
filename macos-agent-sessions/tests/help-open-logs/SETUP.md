# Scenario

**Feature**: Open Logs menu — daemon info, Finder plan, and menu label

```
# daemon info: isolated serve + GET /api/info → storage_path
doctest Run(req) -> build agent-sessions -> serve --state-dir --port -> GET /api/info

# pure logic: Swift test helper mirrors LogsFinderPlan + OpenLogsMenuState
doctest -> logs_finder_plan | open_logs_menu_state -> TestHelper.swift -> reveal_kind, menu_label
```

## Preconditions

- The `agent-sessions` CLI exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")`.
- `GET /api/info` returns `{"storage_path":"...", "port":..., "event_count":...}`.
- Log file path is `{storage_path}/notify-logs.jsonl`.
- **Isolation (mandatory):** Every test uses `stateDir` under `t.TempDir()`; never reads/writes real `~/.os-bar/`.
- Tests use ephemeral ports; never bind production port `38271`.
- Swift test helper is built from `os-bar-agent-sessionsTests/TestHelper.swift` for pure-logic leaves.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Dispatch by `req.Action` in root `Run(t, req)`:
   - `daemon_info` — build CLI, start `serve`, `GET /api/info`
   - `daemon_info_unreachable` — `GET /api/info` on ephemeral port with no daemon
   - `logs_finder_plan` — Swift helper: given `storage_path` + filesystem → reveal plan
   - `open_logs_menu_state` — Swift helper: given `info_error` → label + enabled
2. Leaf `Setup` configures action-specific parameters.
3. Leaf `Assert` validates HTTP status, `storage_path`, reveal plan, or menu state.
4. Return `(*Response, nil)` on success.

## Context

- Path resolution is daemon-only; no `AGENT_SESSIONS_STATE_DIR` / `$HOME` fallback in app code.
- On daemon error: Finder menu label `Show Logs in Finder (daemon unreachable)`, `menu_enabled=false`.
- On success with log file: `reveal_kind=file`, `select_root=storage_path`.
- On success without log file: `reveal_kind=directory`, open `storage_path`.
- No keyboard shortcut; no real Finder in CI.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("help-open-logs: root setup — Run() dispatches by req.Action")
	return nil
}
```