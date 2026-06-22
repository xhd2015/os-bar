# Scenario

**Feature**: integrations routing regression after agent subcommands added

```
# flag-only integrations unchanged
agent-sessions integrations --json --global -> JSON status list

# bash-completions subcommand still routes
agent-sessions integrations bash-completions --install --dry-run -> would install message
```

## Preconditions

- Existing `integrations --json` and `bash-completions` behavior must remain.

## Steps

- Grouping node. Each leaf sets `req.Action` and flags for a routing regression scenario.

## Context

- JSON response must list exactly four integrations (grok, opencode, pi, codex).
- Bash-completions dry-run must not write files under fakeHome.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("routing: preparing integrations routing regression scenario")
	return nil
}
```