# Scenario

**Feature**: split rows when grok global installed but local missing

```
# seed grok globally only, list both scopes
install --grok --global -> integrations -> grok Up to date (Global) + Missing (Local)
```

## Steps

1. Leave `JsonOut`, `Global`, and `Local` false (default dual-scope listing).
2. Set `SeedGrokViaInstall = true` (global only).

## Context

- Different statuses across scopes → two rows per agent with scope suffixes.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = false
	req.Local = false
	req.SeedGrokViaInstall = true
	return nil
}
```