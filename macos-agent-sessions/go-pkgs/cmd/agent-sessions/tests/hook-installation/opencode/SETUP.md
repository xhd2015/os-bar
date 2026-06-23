# Scenario

## Preconditions
- Tests in this subtree install the opencode plugin (`agent-sessions.ts`).

## Steps
- Grouping node. Each leaf sets `req.Target = "opencode"`.

## Context
- Local: `<workDir>/.opencode/plugins/agent-sessions.ts`.
- Global: `<fakeHome>/.config/opencode/plugins/agent-sessions.ts`.
- The `/config add plugin` hint is printed only for global installs after a write.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = "opencode"
	t.Logf("opencode: preparing install test")
	return nil
}
```