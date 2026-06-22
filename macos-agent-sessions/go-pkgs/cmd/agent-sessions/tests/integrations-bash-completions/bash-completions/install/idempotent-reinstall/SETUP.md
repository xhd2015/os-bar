# Scenario

**Feature**: idempotent bash completion reinstall

```
# second --install on unchanged file → up to date
agent-sessions integrations bash-completions --install -> installed
agent-sessions integrations bash-completions --install -> up to date
```

## Steps

1. Set `Install = true` and `RunTwice = true`.

## Context

- Second run must not modify file content.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.RunTwice = true
	return nil
}
```