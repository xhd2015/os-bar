## Steps
1. Preload the store with one event at dir `"/d"` that has `consumed: true`.
2. Call `Run(t, req)` with `action: "add_event"` and `dir: "/d"`.
3. The dedup logic should bump the timestamp and reset `consumed` to `false`.

## Context
- Deduping an existing event not only updates the timestamp but also resets `consumed` to `false`.
- This ensures a re-notified session appears as unconsumed in the UI.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	now := time.Now().UTC()
	oldTime := now.Add(-30 * time.Minute).Format("2006-01-02T15:04:05Z")

	preloaded := []map[string]interface{}{
		{
			"id":        "dddddddd-dddd-4ddd-addd-dddddddddddd",
			"dir":       "/d",
			"timestamp": oldTime,
			"consumed":  true,
		},
	}
	eventsJSON, err := json.Marshal(preloaded)
	if err != nil {
		return fmt.Errorf("failed to marshal preloaded events: %w", err)
	}

	req.Action = "add_event"
	req.Dir = "/d"
	req.EventsJSON = string(eventsJSON)
	return nil
}
```
