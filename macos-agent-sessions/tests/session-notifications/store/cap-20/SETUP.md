## Steps
1. Construct a list of 21 distinct directory paths.
2. Call `Run(t, req)` with `action: "add_events_batch"` and `dirs` set to the 21 paths.
3. The test helper adds all 21 events; the 21st triggers the cap, evicting the oldest by timestamp.

## Context
- The store has a maximum capacity of 20 events.
- When a 21st event is added, the oldest-by-timestamp event is evicted.
- The first event added (index 0 in dirs) should be the oldest and thus evicted.
- After adding 21 events, only 20 should remain.

```go
func Setup(t *testing.T, req *Request) error {
	dirs := make([]string, 21)
	for i := 0; i < 21; i++ {
		dirs[i] = fmt.Sprintf("/Users/test/project-%02d", i)
	}

	req.Action = "add_events_batch"
	req.Dirs = dirs
	return nil
}
```
