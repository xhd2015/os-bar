# Scenario

**Feature**: second append adds a line without array rewrite

```
# two log-only notifies to distinct dirs
harness -> POST /api/notify {"dir":"/proj-a"} -> append line 1
harness -> POST /api/notify {"dir":"/proj-b"} -> append line 2

# disk: 2 lines, no `[` wrapper
```

## Steps

1. POST two log-only notifies with different `dir` values.
2. Read `notify-logs.jsonl` and count lines.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	req.HTTPSteps = []HTTPStep{
		{Method: "POST", Path: "/api/notify", Body: `{"dir":"/proj-a","event":"a"}`},
		{Method: "POST", Path: "/api/notify", Body: `{"dir":"/proj-b","event":"b"}`},
	}
	return nil
}
```