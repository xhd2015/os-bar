# Scenario

**Feature**: Pure label formatting based on daemon port and PID

## Steps

1. Set `req.Action = restart_daemon_label`.
2. Swift test helper computes label from `daemon_port` and `daemon_pid`.
3. Assert label and enabled state.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionRestartDaemonLabel
	return nil
}
```