# Scenario

**Feature**: claude fresh local install via integrations subcommand

```
# local install under workDir
agent-sessions integrations claude --install -> settings.json + stop script
```

## Steps

1. Set `Install = true`, `Global = false`.

## Context

- Must match `agent-sessions install --claude` local behavior.
- The Stop handler command is `AGENT_SESSIONS_AGENT=claude '<scriptPath>'` (command stays absolute).

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.Global = false
	return nil
}
```
