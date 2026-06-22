# Scenario

**Feature**: integrations --json default dual-scope entries

```
# JSON without scope flags returns global+local entries
test -> agent-sessions integrations --json -> 8 entries with scope field
```

## Steps

1. Set `JsonOut = true`, leave `Global` and `Local` false.

## Context

- Breaking change vs prior 4 local-only default: now 8 entries.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = true
	req.Global = false
	req.Local = false
	return nil
}
```