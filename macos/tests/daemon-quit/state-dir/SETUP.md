# Scenario

**Feature**: resolve daemon state directory for pid file lookup

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonQuitPlan
	req.Home = "/Users/tester"
	return nil
}
```