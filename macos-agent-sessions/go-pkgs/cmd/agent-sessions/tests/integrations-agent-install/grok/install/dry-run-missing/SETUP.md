# Scenario

**Feature**: grok dry-run install when hook files are missing

```
# no pre-existing grok hooks → would install, no writes
agent-sessions integrations grok --install --dry-run -> install report
```

## Steps

1. Set `Install = true`, `DryRun = true` on empty workDir.

## Context

- Dry-run must not create grok hook files under workDir or fakeHome.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	return nil
}
```