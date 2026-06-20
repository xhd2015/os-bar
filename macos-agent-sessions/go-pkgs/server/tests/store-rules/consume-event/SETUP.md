# Scenario

**Feature**: POST /api/events/consume marks event consumed

```
# notify creates unconsumed event
harness -> POST /api/notify {dir:/consume-me, source:notify} -> daemon

# consume flips consumed flag
harness -> POST /api/events/consume {"dir":"/consume-me"} -> daemon
harness <- GET /api/list -> consumed:true
```

## Steps

1. POST notify for `/consume-me`.
2. POST `/api/events/consume` with `{"dir":"/consume-me"}`.
3. GET `/api/list`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Dir = "/consume-me"
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/consume-me","source":"notify"}`,
		},
		{
			Method: "POST",
			Path:   "/api/events/consume",
			Body:   `{"dir":"/consume-me"}`,
		},
		{Method: "GET", Path: "/api/list"},
	}
	return nil
}
```