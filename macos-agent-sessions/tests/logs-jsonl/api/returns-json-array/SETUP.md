# Scenario

**Feature**: API body is JSON array despite JSONL on disk

```
harness -> POST /api/notify {"dir":"/api-proj","event":"x"}
harness <- GET /api/logs
```

## Steps

1. POST one log-only notify.
2. GET `/api/logs` as final HTTP step.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	req.HTTPSteps = []HTTPStep{
		{Method: "POST", Path: "/api/notify", Body: `{"dir":"/api-proj","event":"x"}`},
		{Method: "GET", Path: "/api/logs"},
	}
	return nil
}
```