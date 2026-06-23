# Scenario

**Feature**: integrations codex --install, dry-run, global, and flag validation

```
# --install writes codex hooks under workDir or fakeHome
agent-sessions integrations codex --install -> hooks.json + script

# --dry-run reports planned install without writes
agent-sessions integrations codex --install --dry-run -> stdout only
```

## Steps

- Grouping node for codex install, dry-run, global, and error leaves.

## Context

- Fresh local install creates hooks.json with one Stop group and executable stop script.
- Global install writes under fakeHome only.
- Install stdout paths use `pathfmt.Short` (local `.codex/...`, global `~/.codex/...`).
- Successful local install prints a global hint; global install, dry-run, and help omit it.
- Unknown flags must be rejected with exit 1.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("codex/install: narrowing codex install scenario")
	return nil
}
```