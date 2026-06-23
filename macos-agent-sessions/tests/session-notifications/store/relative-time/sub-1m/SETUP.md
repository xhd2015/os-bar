# Scenario

**Feature**: relative time under one minute

```
30s ago -> <1m ago
```

## Steps
1. Pick a fixed reference time as "now" for deterministic output.
2. Compute a timestamp 30 seconds before the reference time.
3. Call `Run(t, req)` with `action: "relative_time"`, `timestamp_iso`, and `reference_iso`.
4. The test helper computes the relative time and returns it in `relative_time`.

## Context
- A timestamp less than 60 seconds before the reference time should produce `"<1m ago"`.
- Using a fixed reference time ensures the test is deterministic across runs.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	refTime := time.Date(2026, 6, 16, 12, 0, 0, 0, time.UTC)
	eventTime := refTime.Add(-30 * time.Second)

	req.Action = "relative_time"
	req.TimestampISO = eventTime.Format("2006-01-02T15:04:05Z")
	req.ReferenceISO = refTime.Format("2006-01-02T15:04:05Z")
	return nil
}
```
