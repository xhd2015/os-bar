# Scenario

**Feature**: integrations --json routing regression guard

```
# flag-only integrations unchanged after subcommand routing added
agent-sessions integrations --json --global -> JSON status list
```

## Preconditions

- Existing `integrations --json` behavior must remain for daemon API consumers.

## Steps

- Grouping node. Sets `req.Action = "integrations"` and `req.JsonOut = true`.

## Context

- Response must be valid JSON with exactly five integration entries (grok, opencode, pi, codex, claude).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations"
	req.JsonOut = true
	t.Logf("routing: preparing integrations JSON regression scenario")
	return nil
}
```