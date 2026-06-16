## Steps
1. Call `Run(t, req)` with `Target: "codex"`, `Global: true`, no pre-existing hooks.

## Context
- Fresh global codex install writes under isolated `fakeHome/.codex/`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "codex"
	req.Global = true
	req.PreExistingHooksJSON = ""
	return nil
}
```