# Scenario

**Feature**: daemon stops when menu bar app quits

```
# app quit selects shutdown target then signals daemon
AppDelegate.applicationWillTerminate -> DaemonShutdown.terminateOnQuit

# helper mirrors target selection; Go leaf verifies SIGTERM stops serve
```

## Preconditions

- Swift test helper built from `os-bar-agent-sessionsTests/TestHelper.swift`.
- Go lifecycle leaf builds `agent-sessions` CLI from `go-pkgs/cmd/agent-sessions`.

## Steps

1. Plan/state-dir/skip leaves call Swift helper actions.
2. Lifecycle leaf starts daemon, sends SIGTERM, asserts health down.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("daemon-quit: root setup")
	return nil
}
```