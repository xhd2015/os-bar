# Scenario

**Feature**: Restart daemon menu item — label formatting and daemon lifecycle

```
# label: Swift test helper computes label from daemon_port + daemon_pid
doctest Run(req) -> TestHelper.swift -> button_label, button_enabled

# restart: Go doctest harness kills and restarts daemon process
doctest Run(req) -> build agent-sessions -> start -> kill -> restart -> health probe
```

## Preconditions

- The `agent-sessions` CLI exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")`.
- Swift test helper is built from `TestHelper.swift` for label tests.
- **Isolation**: Label tests use pure logic (no real daemon); restart tests use temp state dir + ephemeral port.

## Steps

1. Dispatch by `req.Action`:
   - `restart_daemon_label` — Swift test helper computes label from `daemon_port` and `daemon_pid`
   - `daemon_restart` — Go harness kills daemon, starts new one, verifies health

## Context

- Label format: `Restart Daemon (Port: N, PID: M)` when live; `Restart Daemon (Port: -, PID: -)` when not live.
- Button is always enabled.
- Restart involves SIGTERM → wait → spawn new daemon → health probe.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("restart-daemon: root setup — Run() dispatches by req.Action")
	return nil
}
```