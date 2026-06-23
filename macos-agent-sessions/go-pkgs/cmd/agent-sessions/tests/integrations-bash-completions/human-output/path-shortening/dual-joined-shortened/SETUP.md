# Scenario

**Feature**: joined dual-scope paths shorten each side independently

```
# grok installed in both scopes with same status collapses to one row
test -> seed grok global + local -> integrations -> collapsed row

# joined path column shows shortened global + shortened local
human formatter -> pathfmt.Short(global) + " + " + pathfmt.Short(local)
```

## Preconditions

- Grok seeded globally (`SeedGrokViaInstall`) and locally (`SeedGrokLocal`).
- Other agents remain missing in both scopes.

## Steps

1. Set `req.SeedGrokViaInstall = true` and `req.SeedGrokLocal = true`.
2. Run default dual-scope `integrations` (no scope flags).

## Context

- Collapsed grok row label: `Up to date (Global + Local)`.
- Joined path must look like `~/.grok/hooks/agent-sessions.json + .grok/hooks/agent-sessions.json`.

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedGrokViaInstall = true
	req.SeedGrokLocal = true
	t.Logf("path-shortening/dual-joined-shortened: grok both scopes installed")
	return nil
}
```