# Scenario

## Steps
1. Call `Run(t, req)` with `Target: "codex"`, `DryRun: true`, `Global: false`, no pre-existing hooks.

## Context
- Dry-run should report install but not create hooks.json.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "codex"
	req.Global = false
	req.DryRun = true
	req.PreExistingHooksJSON = ""
	return nil
}
```