# Scenario

**Feature**: Button is always enabled regardless of daemon state

```go
func Setup(t *testing.T, req *Request) error {
	req.DaemonPort = -1
	req.DaemonPID = -1
	return nil
}
```