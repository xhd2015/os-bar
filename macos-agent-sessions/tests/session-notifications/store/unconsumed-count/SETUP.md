## Steps
1. Preload the store with 3 events: two unconsumed, one consumed.
2. Call `Run(t, req)` with `action: "unconsumed_count"` and the preloaded `events_json`.
3. The test helper loads the events and returns the `unconsumed_count`.

## Context
- The `unconsumed_count` response field reflects the number of events where `consumed == false`.
- With 2 out of 3 events unconsumed, `unconsumed_count` should be 2.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	now := time.Now().UTC()
	t1 := now.Add(-1 * time.Hour).Format("2006-01-02T15:04:05Z")
	t2 := now.Add(-2 * time.Hour).Format("2006-01-02T15:04:05Z")
	t3 := now.Add(-3 * time.Hour).Format("2006-01-02T15:04:05Z")

	preloaded := []map[string]interface{}{
		{
			"id":        "11111111-1111-1111-1111-111111111111",
			"dir":       "/a",
			"timestamp": t1,
			"consumed":  false,
		},
		{
			"id":        "22222222-2222-2222-2222-222222222222",
			"dir":       "/b",
			"timestamp": t2,
			"consumed":  true,
		},
		{
			"id":        "33333333-3333-3333-3333-333333333333",
			"dir":       "/c",
			"timestamp": t3,
			"consumed":  false,
		},
	}
	eventsJSON, err := json.Marshal(preloaded)
	if err != nil {
		return fmt.Errorf("failed to marshal preloaded events: %w", err)
	}

	req.Action = "unconsumed_count"
	req.EventsJSON = string(eventsJSON)
	return nil
}
```
