# Scenario

**Feature**: human status label mapping with mixed install state

```
# seed grok globally, list with human output
install --grok --global -> agent-sessions integrations --global -> grok Up to date, others Missing
```

## Steps

1. Set `Global = true`, `JsonOut = false`.
2. Set `SeedGrokViaInstall = true` so `Run` installs grok hooks before listing.

## Context

- Validates `up_to_date` → `Up to date` label alongside `missing` → `Missing`.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = true
	req.SeedGrokViaInstall = true
	return nil
}
```