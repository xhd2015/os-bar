# Scenario

**Feature**: integrations codex --help prints subcommand help

```
# explicit --help flag
test -> agent-sessions integrations codex --help -> subcommand help on stdout
```

## Steps

1. Set `Action = "integrations_agent"`, `Agent = "codex"`, `Args = ["--help"]`.

## Context

- `--help` must exit 0 and document install/dry-run/global flags.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_agent"
	req.Agent = "codex"
	req.Args = []string{"--help"}
	return nil
}
```