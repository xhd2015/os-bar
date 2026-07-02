# Scenario

**Feature**: Daemon live (port=38271, pid=12345) → label shows both

```go
func Setup(t *testing.T, req *Request) error {
	req.DaemonPort = 38271
	req.DaemonPID = 12345
	return nil
}
```