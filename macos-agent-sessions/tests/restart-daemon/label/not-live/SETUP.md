# Scenario

**Feature**: Daemon not live (port=-1, pid=-1) → label shows `-, -`

```go
func Setup(t *testing.T, req *Request) error {
	req.DaemonPort = -1
	req.DaemonPID = -1
	return nil
}
```