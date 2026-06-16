## Steps
1. Call `Run(t, req)` with `Target: "grok"`, `Global: false` (installs stop script locally).

## Context
- After grok local install, inspect `agent-sessions-stop.sh` for fallback chain markers.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "grok"
	req.Global = false
	return nil
}
```