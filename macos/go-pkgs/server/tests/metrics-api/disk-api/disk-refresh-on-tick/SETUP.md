# Scenario

**Feature**: advancing mock tick updates disk used bytes while total stays constant

```
# tick 0 snapshot
doctest <- GET /api/metrics -> disk_total=536870912000, disk_used=214748364800

# advance to tick 1
doctest -> POST /api/test/advance-tick -> provider tick++

# tick 1 snapshot
doctest <- GET /api/metrics -> disk_total=536870912000, disk_used=241591910400
```

## Steps

1. Set `req.Action = metrics_tick`.
2. Before/after disk bytes encoded in `MetricsTickResult` via `resp.HTTPBody`.

## Context

- Dedicated disk refresh leaf; existing `refresh-on-tick` remains CPU/MEM only.
- Tick 0→1: used 214748364800→241591910400, total unchanged at 536870912000.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsTick
	return nil
}
```