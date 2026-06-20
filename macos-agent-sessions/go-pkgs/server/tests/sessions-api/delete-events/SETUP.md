# Scenario

**Feature**: DELETE /api/events removes events for a directory

```
# notify creates event for /proj
harness -> POST /api/notify -> daemon -> events.json

# delete removes by dir query param
harness -> DELETE /api/events?dir=/proj -> daemon
harness <- GET /api/list -> []
```

## Steps

1. POST notify with `source=notify` for `/proj`.
2. DELETE `/api/events?dir=/proj`.
3. GET `/api/list`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/proj","source":"notify"}`,
		},
		{Method: "DELETE", Path: "/api/events?dir=/proj"},
		{Method: "GET", Path: "/api/list"},
	}
	return nil
}
```