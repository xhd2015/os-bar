# Scenario

**Feature**: integrations claude subcommand routes to InstallClaude

```
# claude --install delegates to existing install logic
agent-sessions integrations claude --install -> settings.json + stop script
```

## Steps

- Grouping node. Sets `req.Action = "integrations_agent"` and `req.Agent = "claude"`.

## Context

- Claude install paths: local `workDir/.claude/`, global `fakeHome/.claude/`.
- Merge semantics are covered by `tests/hook-installation/`; this suite focuses on routing smoke.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_agent"
	req.Agent = "claude"
	return nil
}
```
