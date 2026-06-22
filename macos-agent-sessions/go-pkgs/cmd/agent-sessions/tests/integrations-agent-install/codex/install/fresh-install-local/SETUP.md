# Scenario

**Feature**: codex fresh local install via integrations subcommand

```
# local install under workDir
agent-sessions integrations codex --install -> hooks.json + stop script
```

## Steps

1. Set `Install = true`, `Global = false`.

## Context

- Must match `agent-sessions install --codex` local behavior.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.Global = false
	return nil
}
```