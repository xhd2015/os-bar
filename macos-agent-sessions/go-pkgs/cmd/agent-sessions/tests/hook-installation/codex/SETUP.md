# Scenario

## Preconditions
- Tests in this subtree install codex Stop notification hooks via `mergeCodexHooks`.
- Codex writes `hooks.json` and `hooks/agent-sessions-stop.sh`.

## Steps
- Grouping node. Each leaf sets `req.Target = "codex"`.

## Context
- Local: `<workDir>/.codex/hooks.json` + `hooks/agent-sessions-stop.sh`.
- Global: `<fakeHome>/.codex/hooks.json` + `hooks/agent-sessions-stop.sh`.
- Merge preserves foreign hooks; only `statusMessage: "os-bar agent-sessions notify"` entries are upserted.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = "codex"
	t.Logf("codex: preparing install test")
	return nil
}
```