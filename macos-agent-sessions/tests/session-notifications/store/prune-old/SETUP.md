## Steps
1. Compute a timestamp from 8 days ago (outside the 7-day window).
2. Construct a preloaded `events_json` array with one event at that timestamp.
3. Call `Run(t, req)` with `action: "prune"` and the preloaded `events_json`.
4. The test helper loads the preloaded events into UserDefaults, runs the prune logic (remove events older than 7 days from now), and returns the remaining events.

## Context
- On load, `SessionStore` must prune events older than 7 days from the current time.
- An event timestamped 8 days ago should be removed by the prune step, resulting in count=0.
- The prune action simulates what happens during `load()` without requiring actual UserDefaults I/O in the test process.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	oldTime := time.Now().Add(-8 * 24 * time.Hour).UTC()
	oldTimestamp := oldTime.Format("2006-01-02T15:04:05Z")

	preloaded := []map[string]string{
		{
			"id":        "00000000-0000-0000-0000-000000000001",
			"dir":       "/Users/test/old-project",
			"timestamp": oldTimestamp,
		},
	}
	eventsJSON, err := json.Marshal(preloaded)
	if err != nil {
		return fmt.Errorf("failed to marshal preloaded events: %w", err)
	}

	req.Action = "prune"
	req.EventsJSON = string(eventsJSON)
	return nil
}
```
