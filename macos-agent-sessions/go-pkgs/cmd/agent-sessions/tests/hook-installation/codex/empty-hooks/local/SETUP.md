# Scenario

## Steps
1. Call `Run(t, req)` with `Target: "codex"`, `Global: false`, no pre-existing hooks.

## Context
- Fresh local codex install creates hooks.json with only our Stop entry plus the stop script.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "codex"
	req.Global = false
	req.PreExistingHooksJSON = ""
	return nil
}
```