# Scenario

**Feature**: OS_BAR_STATE_DIR overrides default

```go
func Setup(t *testing.T, req *Request) error {
	req.StateDirEnvValue = "/tmp/custom-os-bar"
	return nil
}
```