# Scenario

**Feature**: integrations --json --global regression

```
# machine-readable path unchanged
test -> agent-sessions integrations --json --global -> JSON envelope
```

## Steps

1. Set `JsonOut = true` and `Global = true`.

## Context

- Overlaps `routing/integrations-json-unchanged` intent; kept here to anchor human-output group's JSON branch.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = true
	req.Global = true
	return nil
}
```