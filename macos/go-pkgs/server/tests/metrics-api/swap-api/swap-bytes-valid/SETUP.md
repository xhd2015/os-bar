# Scenario

**Feature**: swap used bytes never exceed swap total bytes

```
# mock provider tick 0
doctest <- GET /api/metrics -> 0 <= swap_used_bytes <= swap_total_bytes
```

## Steps

1. Set `req.Action = metrics_fetch`.

## Context

- Invariant check on every mock snapshot; tick 0 has total > used > 0.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsFetch
	return nil
}
```