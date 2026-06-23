# Scenario

**Feature**: local-only installed row under dual-scope default

```
# seed grok locally only, list both scopes
install --grok -> integrations -> grok Up to date (Local); others Missing (Global + Local)
```

## Steps

1. Leave `JsonOut`, `Global`, and `Local` false (default dual-scope listing).
2. Set `SeedGrokLocal = true` (project-local only).

## Context

- Global missing, local non-missing → one `Up to date (Local)` row with local path only.
- Both scopes missing → collapsed `Missing (Global + Local)` with global path.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = false
	req.Local = false
	req.SeedGrokLocal = true
	return nil
}
```