# Scenario

**Feature**: swap byte fields exposed on `/api/metrics` from mock provider

```
# mock provider at tick 0 returns swap totals
doctest <- GET /api/metrics -> swap_total_bytes, swap_used_bytes

# advance-tick updates used bytes while total may stay constant
doctest -> POST /api/test/advance-tick -> provider tick++
doctest <- GET /api/metrics -> updated swap_used_bytes
```

## Preconditions

- Daemon started with `--mock-metrics`.
- Mock tick 0: swap total=2147483648, swap used=104857600.

## Steps

1. Swap API leaves use `metrics_fetch` or `metrics_tick`.
2. `parseMetrics` populates `Response.SwapTotalBytes` and `Response.SwapUsedBytes`.

## Context

- Additive API fields; existing CPU/MEM assertions unchanged.
- Swap used must never exceed swap total.

```go
func Setup(t *testing.T, req *Request) error {
	req.MockMetrics = true
	return nil
}
```