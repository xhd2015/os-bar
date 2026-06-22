# Scenario

**Feature**: fresh bash completion install

```
# empty fakeHome → create completion file
agent-sessions integrations bash-completions --install -> installed message + file
```

## Steps

1. Set `Install = true` on empty fakeHome.

## Context

- Completion file must contain markers for the full agent-sessions command tree.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	return nil
}
```