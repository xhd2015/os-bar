# Scenario

**Feature**: Known port but unknown PID → label shows port, dash for PID

```go
func Setup(t *testing.T, req *Request) error {
	req.DaemonPort = 38271
	req.DaemonPID = -1
	return nil
}
```