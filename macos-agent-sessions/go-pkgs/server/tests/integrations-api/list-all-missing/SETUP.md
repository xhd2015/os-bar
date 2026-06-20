# Scenario

**Feature**: integrations list reports all missing on empty HOME

```
# empty fakeHome — no hook files installed
harness -> serve (HOME=fakeHome) -> daemon

# all four integrations missing
harness <- GET /api/integrations?global=1 -> all status=missing
```

## Steps

1. Start daemon with empty `fakeHome`.
2. GET `/api/integrations?global=1`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPRequest
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/integrations?global=1"
	return nil
}
```