## Steps
1. Preload the store with 3 events having known, distinct timestamps via `events_json`.
2. Call `Run(t, req)` with `action: "add_event"` and a new dir.
3. After the add, the store sorts all events newest-first.

## Context
- The store always maintains events in newest-first order.
- After adding a new event (which gets `timestamp = now`), it should appear at index 0.
- The preloaded events have older timestamps and should appear after the new one.
- Preloaded timestamps: T-10min, T-5min (relative to now). New event gets T=now.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	now := time.Now().UTC()

	t1 := now.Add(-10 * time.Minute).Format("2006-01-02T15:04:05Z")
	t2 := now.Add(-5 * time.Minute).Format("2006-01-02T15:04:05Z")

	preloaded := []map[string]string{
		{
			"id":        "00000000-0000-0000-0000-aaaaaaaaaaaa",
			"dir":       "/Users/test/older-project",
			"timestamp": t1,
		},
		{
			"id":        "00000000-0000-0000-0000-bbbbbbbbbbbb",
			"dir":       "/Users/test/newer-project",
			"timestamp": t2,
		},
	}
	eventsJSON, err := json.Marshal(preloaded)
	if err != nil {
		return fmt.Errorf("failed to marshal preloaded events: %w", err)
	}

	req.Action = "add_event"
	req.Dir = "/Users/test/newest-project"
	req.EventsJSON = string(eventsJSON)
	return nil
}
```
