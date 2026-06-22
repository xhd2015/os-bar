# Scenario

**Feature**: opencode dry-run install when plugin file is missing

```
# no pre-existing opencode plugin → would install, no writes
agent-sessions integrations opencode --install --dry-run -> opencode plugin install report
```

## Steps

1. Set `Install = true`, `DryRun = true` on empty workDir.

## Context

- Dry-run must not create opencode plugin file under workDir or fakeHome.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	return nil
}
```