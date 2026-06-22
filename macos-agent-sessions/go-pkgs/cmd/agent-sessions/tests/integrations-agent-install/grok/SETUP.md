# Scenario

**Feature**: integrations grok subcommand routes to InstallGrok

```
# grok --install delegates to existing install logic
agent-sessions integrations grok --install -> hooks JSON + stop script
```

## Steps

- Grouping node. Sets `req.Action = "integrations_agent"` and `req.Agent = "grok"`.

## Context

- Grok install paths: local `workDir/.grok/hooks/`, global `fakeHome/.grok/hooks/`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_agent"
	req.Agent = "grok"
	return nil
}
```