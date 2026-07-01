# Scenario

**Feature**: wrong HTTP method on /api/events/consume-all returns 405

```
# GET is not allowed on the consume-all endpoint (POST only, matches handleConsume)
harness -> GET /api/events/consume-all -> daemon -> 405
```

## Steps

1. `GET /api/events/consume-all` (consume-all only accepts POST).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPRequest
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/events/consume-all"
	return nil
}
```
