# Scenario

**Feature**: codex fresh global install via integrations subcommand

```
# global install under fakeHome only
agent-sessions integrations codex --install --global -> hooks.json + stop script
```

## Steps

1. Set `Install = true`, `Global = true`.

## Context

- Must match `agent-sessions install --codex --global` behavior.
- No codex files under workDir.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.Global = true
	return nil
}
```