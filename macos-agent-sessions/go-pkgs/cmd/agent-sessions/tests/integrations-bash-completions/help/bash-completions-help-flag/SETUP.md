# Scenario

**Feature**: bash-completions --help flag

```
test -> agent-sessions integrations bash-completions --help -> subcommand help
```

## Steps

1. Set `Action = "integrations_bash_completions"` and `Args = ["--help"]`.

## Context

- Long help flag must exit 0 with usage, flags, and examples.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations_bash_completions"
	req.Args = []string{"--help"}
	return nil
}
```