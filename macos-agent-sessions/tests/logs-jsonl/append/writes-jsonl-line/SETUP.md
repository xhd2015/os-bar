# Scenario

**Feature**: first log-only notify creates a single JSONL line

```
# one log-only notify
harness -> POST /api/notify {"dir":"/proj","event":"start"} -> daemon

# disk: notify-logs.jsonl with 1 valid JSON line ending in \n
```

## Steps

1. POST `/api/notify` without `source=notify`.
2. Read `{stateDir}/notify-logs.jsonl` from disk.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/proj","event":"start"}`,
		},
	}
	return nil
}
```