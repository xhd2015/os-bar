## Steps
1. Open Integrations window from empty `fakeHome`.
2. Capture layout before click, click install button, wait, capture layout after.
3. Assert status badge transition and filesystem side effect.

## Context
- Click-install leaves use `action=sequence`: open → dump → click → wait → dump → teardown.
- v1 installs are global scope (`req.Global = true`).
- Real click via `AXPress` or `CGEvent` (not simulated).

```go
func Setup(t *testing.T, req *Request) error {
	req.Global = true
	return nil
}
```