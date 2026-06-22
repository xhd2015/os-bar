# Scenario

**Feature**: bash-completions subcommand still routes after agent subcommands added

```
# dry-run install via bash-completions subcommand
agent-sessions integrations bash-completions --install --dry-run -> would install message
```

## Steps

1. Set `Action = "integrations_bash_completions"`, `Install = true`, `DryRun = true`.

## Context

- Dry-run must report planned install without creating completion file.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_bash_completions"
	req.Install = true
	req.DryRun = true
	return nil
}
```