# Scenario

## Steps
1. Call `Run(t, req)` with `Action: "install"` and no `Target` (no `--pi/--grok/--codex/--opencode` flags).

## Context
- Validates that the CLI rejects an install invocation with no integration target.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = ""
	req.Global = false
	req.DryRun = false
	return nil
}
```