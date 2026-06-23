# Scenario

**Feature**: integrations default dual-scope human table

```
# no flags: both scopes with bare header
test -> agent-sessions integrations -> Integrations: + 4 collapsed Missing (Global + Local) rows
```

## Steps

1. Leave `JsonOut`, `Global`, and `Local` false (defaults).

## Context

- Empty `fakeHome` and empty `workDir`: all integrations report `Missing` in both scopes.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = false
	req.Local = false
	return nil
}
```