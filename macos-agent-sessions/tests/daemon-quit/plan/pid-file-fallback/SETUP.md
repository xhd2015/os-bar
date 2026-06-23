# Scenario

**Feature**: pid file used when app did not spawn daemon

```go
func Setup(t *testing.T, req *Request) error {
	running := false
	req.SpawnedRunning = &running
	req.PIDFileContents = "4242\n"
	return nil
}
```