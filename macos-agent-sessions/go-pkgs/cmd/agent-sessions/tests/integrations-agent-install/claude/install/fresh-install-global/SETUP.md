# Scenario

**Feature**: claude fresh global install via integrations subcommand

```
# global install under fakeHome only
agent-sessions integrations claude --install --global -> settings.json + stop script
```

## Steps

1. Set `Install = true`, `Global = true`.

## Context

- Must match `agent-sessions install --claude --global` behavior.
- No claude files under workDir.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.Global = true
	return nil
}
```
