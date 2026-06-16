## Steps
1. Call `Run(t, req)` with `Target: "pi"`, `Global: false`.

## Context
- Smoke test: local pi extension is written to the workspace.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "pi"
	req.Global = false
	return nil
}
```