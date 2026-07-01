# Scenario

**Feature**: integrations claude --install, dry-run, global, and flag validation

```
# --install writes claude settings under workDir or fakeHome
agent-sessions integrations claude --install -> settings.json + script

# --dry-run reports planned install without writes
agent-sessions integrations claude --install --dry-run -> stdout only
```

## Steps

- Grouping node for claude install, dry-run, global, and error leaves.

## Context

- Fresh local install creates settings.json with one Stop group and executable stop script.
- Global install writes under fakeHome only.
- Install stdout paths use `pathfmt.Short` (local `.claude/...`, global `~/.claude/...`).
- Successful local install prints a global hint; global install, dry-run, and help omit it.
- Unknown flags must be rejected with exit 1.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("claude/install: narrowing claude install scenario")
	return nil
}
```
