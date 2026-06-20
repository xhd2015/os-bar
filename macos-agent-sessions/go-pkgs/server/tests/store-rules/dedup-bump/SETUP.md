# Scenario

**Feature**: re-notify same dir deduplicates and bumps timestamp

```
# first notify creates event
harness -> POST /api/notify {dir:/d, source:notify} -> daemon

# second notify same dir bumps timestamp, resets consumed
harness -> POST /api/notify {dir:/d, source:notify} -> daemon (dedup)
harness <- GET /api/list -> count=1, newer timestamp
```

## Steps

1. POST two notifies for the same `dir=/d` with `source=notify`.
2. GET `/api/list`.
3. Record first timestamp via small delay between notifies.

```go
import "time"

func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Dir = "/d"
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/d","source":"notify"}`,
		},
	}
	time.Sleep(10 * time.Millisecond)
	req.HTTPSteps = append(req.HTTPSteps,
		HTTPStep{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/d","source":"notify"}`,
		},
		HTTPStep{Method: "GET", Path: "/api/list"},
	)
	return nil
}
```