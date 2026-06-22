# Scenario

**Feature**: nested bash-completions subcommand

```
# integrations dispatches positional bash-completions
agent-sessions integrations bash-completions -> bash-completions handler
```

## Preconditions

- Subcommand routing must not alter `integrations --json` behavior (covered under `routing/`).

## Steps

- Grouping node. Sets `req.Action = "integrations_bash_completions"` for all descendants.

## Context

- Completion path is always under `fakeHome/.config/agent-sessions/bash-completion.bash`.
- Bash profile path is always `fakeHome/.bash_profile`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_bash_completions"
	t.Logf("bash-completions: preparing subcommand scenario")
	return nil
}
```