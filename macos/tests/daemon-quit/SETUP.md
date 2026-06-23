# Scenario

**Feature**: os-bar daemon stops when menu bar app quits

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("daemon-quit: os-bar root setup")
	return nil
}
```