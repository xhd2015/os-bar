# Scenario

**Feature**: integrations --global human table

```
# global scope filter only
test -> agent-sessions integrations --global -> Integrations (global): + 4 rows
```

## Steps

1. Set `Global = true`, leave `JsonOut` and `Local` false.

## Context

- Paths in rows should reference global install locations under `fakeHome`.
- Single-scope mode: no scope suffixes on status labels.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = true
	req.Local = false
	return nil
}
```