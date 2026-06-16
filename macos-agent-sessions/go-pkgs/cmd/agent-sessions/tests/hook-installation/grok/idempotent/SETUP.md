## Steps
1. Call `Run(t, req)` with `Target: "grok"`, `Global: false`, `RunTwice: true`.

## Context
- Second install of unchanged content should report "up to date" without modifying files.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "grok"
	req.Global = false
	req.RunTwice = true
	return nil
}
```