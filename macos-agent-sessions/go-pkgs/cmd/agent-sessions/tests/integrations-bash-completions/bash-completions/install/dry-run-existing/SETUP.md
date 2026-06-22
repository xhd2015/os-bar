# Scenario

**Feature**: dry-run when completion file matches bundled content

```
# bundled content pre-seeded → dry-run reports up to date, no writes
seed install -> agent-sessions integrations bash-completions --install --dry-run -> up to date (dry-run)
```

## Steps

1. Set `Install = true`, `DryRun = true`, `SeedMatchingCompletion = true`.

## Context

- File content after dry-run must remain identical to the seeded bundled version.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.DryRun = true
	req.SeedMatchingCompletion = true
	return nil
}
```