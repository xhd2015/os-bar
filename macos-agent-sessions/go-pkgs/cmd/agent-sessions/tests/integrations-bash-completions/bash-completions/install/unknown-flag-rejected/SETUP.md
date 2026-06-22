# Scenario

**Feature**: unknown flag rejected on bash-completions

```
# unrecognized flag → exit 1
agent-sessions integrations bash-completions --bogus -> stderr error
```

## Steps

1. Set `Args = ["--bogus"]` with no install flags.

## Context

- less-flags must reject unknown flags with `unrecognized flag` on stderr.

```go
func Setup(t *testing.T, req *Request) error {
	req.Args = []string{"--bogus"}
	return nil
}
```