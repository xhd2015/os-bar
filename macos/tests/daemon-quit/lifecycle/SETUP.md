# Scenario

**Feature**: SIGTERM stops agent-sessions daemon (simulates app quit signal)

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonSigtermShutdown
	return nil
}
```