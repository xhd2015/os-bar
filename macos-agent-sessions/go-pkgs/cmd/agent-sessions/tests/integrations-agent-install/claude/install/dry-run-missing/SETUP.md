# Scenario

**Feature**: claude dry-run install when settings.json is missing

```
# no pre-existing settings → would install, no writes
agent-sessions integrations claude --install --dry-run -> claude settings install report
```

## Steps

1. Set `Install = true`, `DryRun = true` on empty workDir.

## Context

- Dry-run must not create settings.json or stop script under workDir.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	return nil
}
```
