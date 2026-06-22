# Scenario

**Feature**: metrics HTTP API returns valid CPU/MEM snapshots from mock provider

```
# mock daemon serves deterministic tick-table metrics
doctest -> serve --mock-metrics -> daemon -> MetricsProvider (mock)

# client reads point-in-time snapshot
doctest <- GET /api/metrics -> {cpu_percent, mem_percent, swap_total_bytes, swap_used_bytes, disk_total_bytes, disk_used_bytes}
```

## Preconditions

- Daemon started with `--mock-metrics`.
- Mock tick 0 returns CPU=45.2, MEM=72.8, swap total=2147483648, swap used=104857600, disk total=536870912000, disk used=214748364800.

## Steps

1. Set `req.MockMetrics = true` and `req.Port = 0`.
2. Metrics leaves use `metrics_fetch` or `metrics_tick` actions; swap/disk format leaves use `format_bytes`, `format_swap_display`, or `format_disk_display`.

## Context

- Parity with legacy `tests/menubar-monitor/` automated leaves.
- Both fields are `float64` in `[0.0, 100.0]`.
- Display rounding is a Swift UI concern; daemon returns raw doubles and uint64 swap bytes.
- Swap format helpers use binary (1024) integer units; no decimals.

```go
func Setup(t *testing.T, req *Request) error {
	req.Port = 0
	req.MockMetrics = true
	return nil
}
```