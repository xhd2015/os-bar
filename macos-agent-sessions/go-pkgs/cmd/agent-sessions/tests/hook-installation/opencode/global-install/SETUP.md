## Steps
1. Call `Run(t, req)` with `Target: "opencode"`, `Global: true`.

## Context
- Global opencode plugin installs under `fakeHome/.config/opencode/plugins/`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "opencode"
	req.Global = true
	return nil
}
```