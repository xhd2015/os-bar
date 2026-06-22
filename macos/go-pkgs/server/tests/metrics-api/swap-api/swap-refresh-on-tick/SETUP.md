# Scenario

**Feature**: advancing mock tick updates swap used bytes while total stays constant

```
# tick 0 snapshot
doctest <- GET /api/metrics -> swap_total=2147483648, swap_used=104857600

# advance to tick 1
doctest -> POST /api/test/advance-tick -> provider tick++

# tick 1 snapshot
doctest <- GET /api/metrics -> swap_total=2147483648, swap_used=157286400
```

## Steps

1. Set `req.Action = metrics_tick`.
2. Before/after swap bytes encoded in `MetricsTickResult` via `resp.HTTPBody`.

## Context

- Dedicated swap refresh leaf; existing `refresh-on-tick` remains CPU/MEM only.
- Tick 0→1: used 104857600→157286400, total unchanged at 2147483648.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsTick
	return nil
}
```