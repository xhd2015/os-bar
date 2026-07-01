# Scenario

## Steps
1. Call `Run(t, req)` with `Target: "claude"`, `DryRun: true`, `Global: false`, no pre-existing settings.

## Context
- Dry-run should report install but not create settings.json.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "claude"
	req.Global = false
	req.DryRun = true
	req.PreExistingHooksJSON = ""
	return nil
}
```
