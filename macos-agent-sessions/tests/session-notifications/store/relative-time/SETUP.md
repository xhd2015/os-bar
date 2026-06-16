## Preconditions
- All tests in this subtree validate the `relativeTime(for:)` formatting logic.
- The test helper computes the relative time between `timestamp_iso` and `reference_iso` (or current time if `reference_iso` is omitted).

## Steps
- This is a grouping node. Specific steps are defined in each leaf.

## Context
- Each leaf provides a specific timestamp (relative to a fixed reference time) and expects a specific formatted string.
- Format rules:
  - < 1 minute: `"<1m ago"`
  - 1-59 minutes: `"Xm ago"` (X = whole minutes)
  - 1-23 hours: `"Xh ago"` (X = whole hours)
  - 1-7 days: `"Xd ago"` (X = whole days)

```go
func Setup(t *testing.T, req *Request) error {
	// All relative-time leaves set Action to "relative_time"
	req.Action = "relative_time"
	return nil
}
```
