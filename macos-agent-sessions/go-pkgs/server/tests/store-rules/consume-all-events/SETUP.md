# Scenario

**Feature**: POST /api/events/consume-all marks every event consumed, preserving count

```
# three distinct dirs notified as unconsumed events
harness -> POST /api/notify {dir:/a, source:notify} -> daemon
harness -> POST /api/notify {dir:/b, source:notify} -> daemon
harness -> POST /api/notify {dir:/c, source:notify} -> daemon

# /a is consumed individually first (mixed pre-state)
harness -> POST /api/events/consume {"dir":"/a"} -> daemon

# bulk consume flips the remaining (and the already-consumed) to consumed
harness -> POST /api/events/consume-all (empty body) -> daemon
harness <- GET /api/list -> 3 events, all consumed=true
```

## Steps

1. POST notify for `/a`, `/b`, `/c` (three unconsumed events).
2. POST `/api/events/consume` with `{"dir":"/a"}` so `/a` is already consumed.
3. POST `/api/events/consume-all` with an empty body.
4. GET `/api/list`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/a","source":"notify"}`,
		},
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/b","source":"notify"}`,
		},
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/c","source":"notify"}`,
		},
		{
			Method: "POST",
			Path:   "/api/events/consume",
			Body:   `{"dir":"/a"}`,
		},
		{
			Method: "POST",
			Path:   "/api/events/consume-all",
		},
		{Method: "GET", Path: "/api/list"},
	}
	return nil
}
```
