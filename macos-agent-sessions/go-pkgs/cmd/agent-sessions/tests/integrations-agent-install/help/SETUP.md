# Scenario

**Feature**: help text for integrations and agent subcommands

```
# integrations --help shows generic agent install example
test -> agent-sessions integrations --help -> Examples with agent install line

# bare agent subcommand prints subcommand help
test -> agent-sessions integrations codex -> subcommand help on stdout
```

## Preconditions

- Help scenarios exercise read-only CLI invocations; no file writes expected.

## Steps

- Grouping node. Each leaf sets `req.Action`, `req.Agent`, and args for a help-only invocation.

## Context

- `integrations --help` must include a generic agent install example (e.g. `integrations codex --install`).
- Bare `integrations codex` must print the same help as `--help` and document `--install`, `--dry-run`, and `--global`.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("help: preparing help text scenario")
	return nil
}
```