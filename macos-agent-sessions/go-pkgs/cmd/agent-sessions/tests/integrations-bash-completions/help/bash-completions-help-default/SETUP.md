# Scenario

**Feature**: bare bash-completions prints subcommand help

```
# no flags → same help as --help
test -> agent-sessions integrations bash-completions -> subcommand help
test -> agent-sessions integrations bash-completions --help -> reference help
```

## Steps

1. Set `Action = "integrations_bash_completions"` with no extra args.
2. Enable `CaptureHelpReference` to capture `--help` output for comparison.

## Context

- Bare invocation must exit 0 and match the `--help` reference byte-for-byte on stdout.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_bash_completions"
	req.CaptureHelpReference = true
	return nil
}
```