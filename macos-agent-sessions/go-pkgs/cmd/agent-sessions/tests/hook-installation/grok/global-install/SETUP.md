## Steps
1. Call `Run(t, req)` with `Target: "grok"`, `Global: true`.

## Context
- Global grok install resolves paths under isolated `fakeHome`, never the real user home.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "grok"
	req.Global = true
	return nil
}
```