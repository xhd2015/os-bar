# Scenario

**Feature**: codex dry-run install when hooks.json is missing

```
# no pre-existing hooks → would install, no writes
agent-sessions integrations codex --install --dry-run -> codex hooks install report
```

## Steps

1. Set `Install = true`, `DryRun = true` on empty workDir.

## Context

- Dry-run must not create hooks.json or stop script under workDir.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	return nil
}
```