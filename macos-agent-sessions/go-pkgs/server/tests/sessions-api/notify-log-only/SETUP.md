# Scenario

**Feature**: notify without source=notify is log-only

```
# notify without source=notify appends log only
harness -> POST /api/notify {"dir":"/proj","event":"x"} -> daemon -> notify-logs.json

# session store stays empty
harness <- GET /api/list -> []
harness <- GET /api/logs -> [{dir:/proj}]
```

## Steps

1. POST notify without `source=notify`.
2. GET `/api/list` — expect empty.
3. GET `/api/logs` — expect one entry.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/proj","event":"x"}`,
		},
		{Method: "GET", Path: "/api/list"},
		{Method: "GET", Path: "/api/logs"},
	}
	return nil
}
```