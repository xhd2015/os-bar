# Scenario

**Feature**: CPU percentage from metrics API is within valid range

```
# mock provider at tick 0
doctest <- GET /api/metrics -> cpu_percent=45.2
```

## Steps

1. Set `req.Action = metrics_fetch`.
2. `Run` starts mock daemon and fetches `/api/metrics`.

## Context

- Hard assert: `cpu_percent ∈ [0.0, 100.0]`.
- Mock tick 0 exact value 45.2 is logged but not a hard assert.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsFetch
	return nil
}
```