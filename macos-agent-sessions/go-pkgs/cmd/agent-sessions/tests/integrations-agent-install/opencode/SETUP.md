# Scenario

**Feature**: integrations opencode subcommand routes to CheckAndWrite for plugin

```
# opencode --install delegates to existing install logic
agent-sessions integrations opencode --install -> plugin file under .opencode/
```

## Steps

- Grouping node. Sets `req.Action = "integrations_agent"` and `req.Agent = "opencode"`.

## Context

- OpenCode install path: local `workDir/.opencode/plugins/agent-sessions.ts`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_agent"
	req.Agent = "opencode"
	return nil
}
```