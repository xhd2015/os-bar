## Preconditions
- Smoke tests for pi extension install.

## Steps
- Grouping node. Leaves set `req.Target = "pi"`.

## Context
- Local: `<workDir>/.pi/extensions/agent-sessions-hook.ts`.
- Global: `<fakeHome>/.pi/agent/extensions/agent-sessions-hook.ts`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = "pi"
	t.Logf("pi: preparing install test")
	return nil
}
```