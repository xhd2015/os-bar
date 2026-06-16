## Steps
1. Call `Run(t, req)` with `Target: "opencode"`, `Global: false`.

## Context
- Local opencode install must not print the stale global-only `/config add plugin` warning.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "opencode"
	req.Global = false
	return nil
}
```