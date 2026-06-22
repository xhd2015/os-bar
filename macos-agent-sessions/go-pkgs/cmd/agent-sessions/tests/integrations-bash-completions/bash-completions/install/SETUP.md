# Scenario

**Feature**: bash-completions --install, profile sourcing, and dry-run

```
# --install writes embedded completion script and updates bash profile
agent-sessions integrations bash-completions --install -> completion file + profile

# --dry-run reports planned action without writes
agent-sessions integrations bash-completions --install --dry-run -> stdout only
```

## Steps

- Grouping node for install, update, dry-run, profile, and validation leaves.

## Context

- Fresh install creates `bash-completion.bash` with mode `0644` and appends profile source block when absent.
- Profile edit is skipped when `.config/agent-sessions/bash-completion.bash` substring already present.
- Stale pre-seed uses `staleCompletionContent` from root helpers.
- Unknown flags must be rejected by less-flags with exit 1.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("bash-completions/install: narrowing install scenario")
	return nil
}
```