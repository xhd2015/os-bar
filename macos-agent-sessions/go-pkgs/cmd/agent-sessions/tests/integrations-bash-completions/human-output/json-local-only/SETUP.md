# Scenario

**Feature**: integrations --json --local entries

```
# JSON with local filter returns 5 local-scoped entries
test -> agent-sessions integrations --json --local -> 5 entries scope=local
```

## Steps

1. Set `JsonOut = true` and `Local = true`, leave `Global` false.

## Context

- New JSON mode for project-local scope only.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = true
	req.Global = false
	req.Local = true
	return nil
}
```