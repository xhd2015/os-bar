## Steps
1. Call `Run(t, req)` with `Target: "grok"`, `Global: false`.

## Context
- Local grok install writes hook config and stop script under the workspace `workDir`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "grok"
	req.Global = false
	return nil
}
```