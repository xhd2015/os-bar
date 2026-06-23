# Scenario

**Feature**: collapsed row when grok installed in both scopes

```
# seed grok globally and locally, list both scopes
install --grok --global + install --grok -> integrations -> grok Up to date (Global + Local)
```

## Steps

1. Leave `JsonOut`, `Global`, and `Local` false (default dual-scope listing).
2. Set `SeedGrokViaInstall = true` and `SeedGrokLocal = true`.

## Context

- Same non-missing status in both scopes collapses to one row per agent.
- Other agents remain missing in both scopes → one `Missing (Global + Local)` row each.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = false
	req.Local = false
	req.SeedGrokViaInstall = true
	req.SeedGrokLocal = true
	return nil
}
```