# Scenario

**Feature**: 201st log entry triggers cap compaction

```
# 201 distinct log-only notifies
harness -> POST /api/notify {"dir":"/proj-NN"} x201

# notify-logs.jsonl has ≤200 lines; /proj-00 gone
```

## Steps

1. POST 201 log-only notifies with dirs `/proj-00` through `/proj-200`.
2. Read `notify-logs.jsonl` from disk.

```go
import "fmt"

func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	for i := 0; i < 201; i++ {
		dir := fmt.Sprintf("/proj-%02d", i)
		req.HTTPSteps = append(req.HTTPSteps, HTTPStep{
			Method: "POST",
			Path:   "/api/notify",
			Body:   fmt.Sprintf(`{"dir":%q,"event":"cap"}`, dir),
		})
	}
	return nil
}
```