# Scenario

**Feature**: both CPU and MEM metrics are present and valid in a single snapshot

```
# mock provider at tick 0 returns both fields
doctest <- GET /api/metrics -> {cpu_percent:45.2, mem_percent:72.8}
```

## Steps

1. Set `req.Action = metrics_fetch`.
2. `Run` fetches `/api/metrics` and parses both fields.

## Context

- Parity with legacy `menubar-monitor/metrics-range/both-valid`.
- In mock mode both values are non-zero.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsFetch
	return nil
}
```