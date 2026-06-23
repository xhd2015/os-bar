# Scenario

## Steps
1. Call `Run(t, req)` with `Target: "grok"`, `DryRun: true`, `Global: false`.

## Context
- Dry-run reports what would be installed but must not write files.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "grok"
	req.Global = false
	req.DryRun = true
	return nil
}
```