# Scenario

**Feature**: integrations codex subcommand routes to InstallCodex

```
# codex --install delegates to existing install logic
agent-sessions integrations codex --install -> hooks.json + stop script
```

## Steps

- Grouping node. Sets `req.Action = "integrations_agent"` and `req.Agent = "codex"`.

## Context

- Codex install paths: local `workDir/.codex/`, global `fakeHome/.codex/`.
- Merge semantics are covered by `tests/hook-installation/`; this suite focuses on routing smoke.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_agent"
	req.Agent = "codex"
	return nil
}
```