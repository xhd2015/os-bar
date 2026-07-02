# Scenario

**Feature**: Daemon restart lifecycle — stop + start + health probe passed

## Steps

1. Start daemon → health OK.
2. SIGTERM → health DOWN.
3. Start new daemon on same port → health OK.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonRestart
	return nil
}
```