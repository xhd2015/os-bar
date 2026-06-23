# Scenario

**Feature**: single-scope global paths display with tilde prefix

```
# --global lists only HOME-scoped install locations
test -> agent-sessions integrations --global -> Integrations (global): table

# each row path is shortened to ~/.config/... or ~/.grok/... etc.
human formatter -> pathfmt.Short -> ~/... on stdout
```

## Preconditions

- Empty `fakeHome` and `workDir`; no integrations installed.

## Steps

1. Set `req.Global = true` (single-scope global human table).

## Context

- All four agents are `Missing` with global paths only.
- Expected display paths start with `~` and must not contain `resp.FakeHome`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Global = true
	t.Logf("path-shortening/global-tilde-paths: global scope, all missing")
	return nil
}
```