# Scenario

**Feature**: notify with source=notify adds a session event

```
# notify with source=notify writes to session store
harness -> POST /api/notify {"dir":"/proj","source":"notify"} -> daemon -> events.json

# list returns the new unconsumed event
harness <- GET /api/list -> [{dir:/proj, consumed:false}]
```

## Steps

1. POST notify with `source=notify` and `dir=/proj`.
2. GET `/api/list` to read session events.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/proj","source":"notify","event":"session.finished"}`,
		},
		{Method: "GET", Path: "/api/list"},
	}
	return nil
}
```