# Scenario

**Feature**: integrations --global --local equals default

```
# both scope flags: same dual-scope listing as default
test -> agent-sessions integrations --global --local -> Integrations: + 5 collapsed rows
```

## Steps

1. Set `Global = true` and `Local = true`, leave `JsonOut` false.

## Context

- Scope flag matrix: `--global --local` checks both scopes with same output as bare `integrations`.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = true
	req.Local = true
	return nil
}
```