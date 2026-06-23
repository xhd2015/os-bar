# Scenario

**Feature**: spawned PID takes priority

```go
func Setup(t *testing.T, req *Request) error {
	spawned := 1234
	running := true
	req.SpawnedPID = &spawned
	req.SpawnedRunning = &running
	req.PIDFileContents = "5678"
	return nil
}
```