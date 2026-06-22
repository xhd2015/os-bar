# Scenario

**Feature**: pi dry-run install when extension file is missing

```
# no pre-existing pi extension → would install, no writes
agent-sessions integrations pi --install --dry-run -> pi extension install report
```

## Steps

1. Set `Install = true`, `DryRun = true` on empty workDir.

## Context

- Dry-run must not create pi extension file under workDir or fakeHome.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	return nil
}
```