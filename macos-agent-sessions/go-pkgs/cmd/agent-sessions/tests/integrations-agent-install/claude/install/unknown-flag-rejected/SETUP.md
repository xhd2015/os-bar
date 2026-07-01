# Scenario

**Feature**: claude subcommand rejects unknown flags

```
# invalid flag before install logic
agent-sessions integrations claude --bogus -> exit 1
```

## Steps

1. Set `Args = ["--bogus"]` without `--install`.

## Context

- CLI must reject unknown flags via less-flags with exit 1.

```go
func Setup(t *testing.T, req *Request) error {
	req.Args = []string{"--bogus"}
	return nil
}
```
