# Scenario

**Feature**: `/api/metrics` response includes swap byte fields at mock tick 0

```
# mock provider tick 0
doctest <- GET /api/metrics -> swap_total_bytes=2147483648, swap_used_bytes=104857600
```

## Steps

1. Set `req.Action = metrics_fetch`.

## Context

- Parity with requirement leaf `swap-bytes-present`.
- Fields must be present and parseable as `uint64`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsFetch
	return nil
}
```