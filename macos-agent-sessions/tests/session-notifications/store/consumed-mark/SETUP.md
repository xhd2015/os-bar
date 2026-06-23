# Scenario

**Feature**: markConsumed flips consumed true

```
mark_consumed -> consumed=true
```

## Steps
1. Preload the store with one event at dir `"/m"` with `consumed: false`.
2. Call `Run(t, req)` with `action: "mark_consumed"` and `dir: "/m"`.
3. Capture the `Response` with the updated event and `unconsumed_count`.

## Context
- `markConsumed(dir:)` sets `consumed = true` on the event matching the given dir.
- After marking, `unconsumed_count` should be 0.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	now := time.Now().UTC()
	ts := now.Format("2006-01-02T15:04:05Z")

	preloaded := []map[string]interface{}{
		{
			"id":        "11111111-1111-4a11-a111-111111111111",
			"dir":       "/m",
			"timestamp": ts,
			"consumed":  false,
		},
	}
	eventsJSON, err := json.Marshal(preloaded)
	if err != nil {
		return fmt.Errorf("failed to marshal preloaded events: %w", err)
	}

	req.Action = "mark_consumed"
	req.Dir = "/m"
	req.EventsJSON = string(eventsJSON)
	return nil
}
```
