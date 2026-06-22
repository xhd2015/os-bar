# Scenario

**Feature**: help text for integrations and bash-completions subcommand

```
# integrations --help shows Examples block
test -> agent-sessions integrations --help -> stdout with Examples

# bare bash-completions prints subcommand help
test -> agent-sessions integrations bash-completions -> subcommand help on stdout
```

## Preconditions

- Help scenarios exercise read-only CLI invocations; no file writes expected.

## Steps

- Grouping node. Each leaf sets `req.Action` and args for a help-only invocation.

## Context

- `integrations --help` must document human-default flags and an `Examples:` section with four example commands.
- Bare `integrations bash-completions` must print the same help as `--help`.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("help: preparing help text scenario")
	return nil
}
```