# Scenario

**Feature**: daemon health fails and pid file removed after SIGTERM

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonSigtermShutdown
	req.Port = 0
	t.Logf("lifecycle/sigterm-stops-daemon: start daemon then SIGTERM")
	return nil
}
```