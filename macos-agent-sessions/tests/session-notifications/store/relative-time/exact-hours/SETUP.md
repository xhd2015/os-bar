## Steps
1. Pick a fixed reference time as "now".
2. Compute a timestamp exactly 2 hours before the reference time.
3. Call `Run(t, req)` with `action: "relative_time"`, `timestamp_iso`, and `reference_iso`.

## Context
- A timestamp 2 hours before the reference time should produce `"2h ago"`.
- This tests the transition from minute-based to hour-based formatting.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	refTime := time.Date(2026, 6, 16, 12, 0, 0, 0, time.UTC)
	eventTime := refTime.Add(-2 * time.Hour)

	req.Action = "relative_time"
	req.TimestampISO = eventTime.Format("2006-01-02T15:04:05Z")
	req.ReferenceISO = refTime.Format("2006-01-02T15:04:05Z")
	return nil
}
```
