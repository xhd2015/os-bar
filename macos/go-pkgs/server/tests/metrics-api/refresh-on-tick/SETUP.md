# Scenario

**Feature**: mock provider advances tick and metrics refresh

```
# initial snapshot at tick 0
doctest <- GET /api/metrics -> cpu=45.2, mem=72.8

# advance mock tick
doctest -> POST /api/test/advance-tick -> provider tick++

# updated snapshot at tick 1
doctest <- GET /api/metrics -> cpu=52.3, mem=68.1
```

## Steps

1. Set `req.Action = metrics_tick`.
2. `Run` performs fetch → advance-tick → fetch sequence.
3. Before/after values encoded in `resp.HTTPBody` as `MetricsTickResult` JSON.

## Context

- Parity with legacy `menubar-monitor/refresh/updates-on-tick`.
- Hard assert: at least one metric changes between before and after.
- Expected tick 0→1 transition: CPU 45.2→52.3, MEM 72.8→68.1.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsTick
	return nil
}
```