# Scenario

**Feature**: agent-sessions install writes Claude Code Stop notification hooks

```
# --claude delegates to Claude install logic (settings.json + stop script)
agent-sessions install --claude -> .claude/settings.json + .claude/hooks/agent-sessions-stop.sh

# merge preserves top-level keys + foreign hooks, upserts only our Stop handler
pre-existing settings.json <- MergeClaudeHooks -> merged settings.json
```

## Preconditions

- Tests in this subtree install claude Stop notification hooks via `MergeClaudeHooks`.
- Claude writes `settings.json` and `hooks/agent-sessions-stop.sh`.

## Steps

- Grouping node. Each leaf sets `req.Target = "claude"`.

## Context

- Local: `<workDir>/.claude/settings.json` + `hooks/agent-sessions-stop.sh`.
- Global: `<fakeHome>/.claude/settings.json` + `hooks/agent-sessions-stop.sh`.
- Claude `settings.json` holds many top-level keys; `MergeClaudeHooks` preserves them all
  and upserts only our `Stop` handler (identified by `statusMessage`).
- Claude has no per-hook `env`; the agent id is conveyed via the
  `AGENT_SESSIONS_AGENT=claude '<script>'` command prefix.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = "claude"
	t.Logf("claude: preparing install test")
	return nil
}
```
