# Scenario

**Feature**: disk used bytes never exceed disk total on `/api/metrics`

```
# mock provider tick 0
doctest <- GET /api/metrics -> 0 <= disk_used_bytes <= disk_total_bytes
```

## Steps

1. Set `req.Action = metrics_fetch`.

## Context

- Validates constraint from requirement: `0 <= disk_used_bytes <= disk_total_bytes`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsFetch
	return nil
}
```