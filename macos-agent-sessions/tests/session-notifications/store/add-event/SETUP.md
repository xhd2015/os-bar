# Scenario

**Feature**: add one event to empty store

```
add_event(/a) -> count=1
```

## Steps
1. Call `Run(t, req)` with `action: "add_event"` and `dir: "/Users/test/project-a"`.
2. Capture the `Response` with the updated `events` array and `count`.

## Context
- This leaf validates the most basic store operation: adding one event to an empty store.
- After the call, the store should contain exactly one event with the given dir.
- The event should have a non-empty `id` (UUID) and `timestamp` (ISO8601).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "add_event"
	req.Dir = "/Users/test/project-a"
	return nil
}
```
