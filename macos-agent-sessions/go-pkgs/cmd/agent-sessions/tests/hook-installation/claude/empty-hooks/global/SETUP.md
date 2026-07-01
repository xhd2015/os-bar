# Scenario

## Steps
1. Call `Run(t, req)` with `Target: "claude"`, `Global: true`, no pre-existing settings.

## Context
- Fresh global claude install writes under isolated `fakeHome/.claude/`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "claude"
	req.Global = true
	req.PreExistingHooksJSON = ""
	return nil
}
```
