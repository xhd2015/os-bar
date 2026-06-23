# Scenario

**Feature**: global-only installed row when local scope missing

```
# seed grok globally only, list both scopes
install --grok --global -> integrations -> grok Up to date (Global); others Missing (Global + Local)
```

## Steps

1. Leave `JsonOut`, `Global`, and `Local` false (default dual-scope listing).
2. Set `SeedGrokViaInstall = true` (global only).

## Context

- Global installed, local missing → one `Up to date (Global)` row; both missing → collapsed `Missing (Global + Local)`.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = false
	req.Local = false
	req.SeedGrokViaInstall = true
	return nil
}
```