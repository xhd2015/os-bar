# Scenario

**Feature**: dual-scope default output never leaks harness absolute paths

```
# default integrations lists both scopes with bare header
test -> agent-sessions integrations -> Integrations: dual-scope table

# both-missing rows show shortened global path only
human formatter -> pathfmt.Short(globalPath) -> no /var/folders/... in stdout
```

## Preconditions

- Empty `fakeHome` and `workDir`; default scope flags (both scopes).

## Steps

1. Use inherited default `Request` (no scope or seed flags).

## Context

- Regression guard: human stdout must not echo `resp.FakeHome`, `resp.WorkDir`, or macOS temp-dir prefixes.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("path-shortening/no-absolute-leak: default dual-scope, all missing")
	return nil
}
```