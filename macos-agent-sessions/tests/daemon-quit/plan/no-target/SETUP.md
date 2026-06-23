# Scenario

**Feature**: no shutdown when neither spawn nor pid file available

```go
func Setup(t *testing.T, req *Request) error {
	running := false
	req.SpawnedRunning = &running
	return nil
}
```