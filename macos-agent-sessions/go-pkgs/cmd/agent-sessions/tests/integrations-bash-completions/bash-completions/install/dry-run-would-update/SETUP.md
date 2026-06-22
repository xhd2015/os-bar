# Scenario

**Feature**: dry-run when completion file is stale

```
# stale pre-seed → would update, file unchanged
pre-seed stale -> agent-sessions integrations bash-completions --install --dry-run -> would update
```

## Steps

1. Set `Install = true`, `DryRun = true`, `PreExistingCompletion = staleCompletionContent`.

## Context

- Dry-run must leave stale content on disk.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	req.PreExistingCompletion = staleCompletionContent
	return nil
}
```