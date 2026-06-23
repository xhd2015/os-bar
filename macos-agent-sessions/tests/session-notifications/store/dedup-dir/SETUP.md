# Scenario

**Feature**: dedup bumps timestamp for same dir

```
add_event(/x) twice -> count=1, newer timestamp
```

## Steps
1. Call `Run(t, req)` with `action: "add_events_batch"` and `dirs: ["/Users/test/project-x", "/Users/test/project-x"]`.
2. The test helper calls `addEvent` twice for the same dir.
3. Capture the `Response` with the final events array and count.

## Context
- This leaf validates the dedup-by-dir rule: when a new event arrives with a directory that already exists in the store, instead of creating a duplicate, the existing event's timestamp is updated to now (bumped to newest).
- Two consecutive additions of the same dir should result in exactly one event.
- The event's timestamp should reflect the second (most recent) addition.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "add_events_batch"
	req.Dirs = []string{"/Users/test/project-x", "/Users/test/project-x"}
	return nil
}
```
