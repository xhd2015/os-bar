# Scenario

**Feature**: session store caps at 20 events, evicting oldest

```
# 21 distinct dirs each get a notify event
harness -> POST /api/notify (x21, distinct dirs) -> daemon

# list returns exactly 20 (oldest evicted)
harness <- GET /api/list -> len=20
```

## Steps

1. POST 21 notifies with dirs `/proj-00` … `/proj-20`.
2. GET `/api/list`.

```go
import "fmt"

func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	for i := 0; i < 21; i++ {
		dir := fmt.Sprintf("/proj-%02d", i)
		req.HTTPSteps = append(req.HTTPSteps, HTTPStep{
			Method: "POST",
			Path:   "/api/notify",
			Body:   fmt.Sprintf(`{"dir":%q,"source":"notify"}`, dir),
		})
	}
	req.HTTPSteps = append(req.HTTPSteps, HTTPStep{Method: "GET", Path: "/api/list"})
	return nil
}
```