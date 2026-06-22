# Scenario

**Feature**: integrations pi subcommand routes to CheckAndWrite for pi extension

```
# pi --install delegates to existing install logic
agent-sessions integrations pi --install -> extension file under .pi/
```

## Steps

- Grouping node. Sets `req.Action = "integrations_agent"` and `req.Agent = "pi"`.

## Context

- Pi install path: local `workDir/.pi/extensions/agent-sessions-hook.ts`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_agent"
	req.Agent = "pi"
	return nil
}
```