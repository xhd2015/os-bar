# Scenario

**Feature**: dry-run install when completion file is missing

```
# no pre-existing file → would install, no writes
agent-sessions integrations bash-completions --install --dry-run -> would install
```

## Steps

1. Set `Install = true`, `DryRun = true` on empty fakeHome.

## Context

- Dry-run must not create directories or files.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	return nil
}
```