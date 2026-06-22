# Scenario

**Feature**: `/api/metrics` response includes disk byte fields at mock tick 0

```
# mock provider tick 0
doctest <- GET /api/metrics -> disk_total_bytes=536870912000, disk_used_bytes=214748364800
```

## Steps

1. Set `req.Action = metrics_fetch`.

## Context

- Parity with requirement leaf `disk-bytes-present`.
- Fields must be present and parseable as `uint64`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMetricsFetch
	return nil
}
```