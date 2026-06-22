# Scenario

**Feature**: disk byte fields exposed on `/api/metrics` from mock provider

```
# mock provider at tick 0 returns root volume disk totals
doctest <- GET /api/metrics -> disk_total_bytes, disk_used_bytes

# advance-tick updates used bytes while total may stay constant
doctest -> POST /api/test/advance-tick -> provider tick++
doctest <- GET /api/metrics -> updated disk_used_bytes
```

## Preconditions

- Daemon started with `--mock-metrics`.
- Mock tick 0: disk total=536870912000, disk used=214748364800.

## Steps

1. Disk API leaves use `metrics_fetch` or `metrics_tick`.
2. `parseMetrics` populates `Response.DiskTotalBytes` and `Response.DiskUsedBytes`.

## Context

- Additive API fields; existing CPU/MEM/swap assertions unchanged.
- Disk used must never exceed disk total.
- Root volume `/` via `disk.Usage("/")` in production; mock tick table in tests.

```go
func Setup(t *testing.T, req *Request) error {
	req.MockMetrics = true
	return nil
}
```