# Scenario

**Feature**: fresh daemon returns empty session list

```
# no prior events in state dir
harness -> serve (empty state) -> daemon

# list is empty array
harness <- GET /api/list -> []
```

## Steps

1. Start daemon with empty state (no seed).
2. GET `/api/list`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPRequest
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/list"
	return nil
}
```