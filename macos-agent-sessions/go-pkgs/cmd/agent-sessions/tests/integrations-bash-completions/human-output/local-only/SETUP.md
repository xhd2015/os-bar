# Scenario

**Feature**: integrations --local human table

```
# local scope filter only
test -> agent-sessions integrations --local -> Integrations (local): + 4 rows
```

## Steps

1. Set `Local = true`, leave `JsonOut` and `Global` false.

## Context

- Single-scope mode: no `(Global)` / `(Local)` suffixes on status labels.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = false
	req.Local = true
	return nil
}
```