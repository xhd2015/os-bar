# Scenario

## Steps
1. Call `Run(t, req)` with `Target: "claude"`, `Global: false`, no pre-existing settings.

## Context
- Fresh local claude install creates settings.json with only our Stop entry plus the stop script.
- The Stop handler command is `AGENT_SESSIONS_AGENT=claude '<scriptPath>'` (no `env` field).

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "claude"
	req.Global = false
	req.PreExistingHooksJSON = ""
	return nil
}
```
