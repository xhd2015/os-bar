# Scenario

**Feature**: split rows when both scopes installed with different statuses

```
# seed grok globally and locally, corrupt local hooks, list both scopes
install --grok --global + install --grok + corrupt local -> integrations -> grok Up to date (Global) + Outdated (Local)
```

## Steps

1. Leave `JsonOut`, `Global`, and `Local` false (default dual-scope listing).
2. Set `SeedGrokViaInstall = true`, `SeedGrokLocal = true`, and `CorruptGrokLocalHooks = true`.

## Context

- Both scopes non-missing with different statuses → two rows with `(Global)` and `(Local)` suffixes.
- Agents missing in both scopes → collapsed `Missing (Global + Local)`.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = false
	req.Local = false
	req.SeedGrokViaInstall = true
	req.SeedGrokLocal = true
	req.CorruptGrokLocalHooks = true
	return nil
}
```