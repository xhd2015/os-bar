# Scenario

**Feature**: bare integrations codex prints subcommand help

```
# no flags → same help as --help
test -> agent-sessions integrations codex -> subcommand help
test -> agent-sessions integrations codex --help -> reference help
```

## Steps

1. Set `Action = "integrations_agent"`, `Agent = "codex"`.
2. Enable `CaptureHelpReference` to capture `--help` output for comparison.

## Context

- Bare invocation must exit 0 and match the `--help` reference byte-for-byte on stdout.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_agent"
	req.Agent = "codex"
	req.CaptureHelpReference = true
	return nil
}
```