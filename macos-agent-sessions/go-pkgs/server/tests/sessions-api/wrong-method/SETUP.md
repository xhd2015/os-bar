# Scenario

**Feature**: wrong HTTP method on /api/notify returns 405

```
# GET is not allowed on notify endpoint
harness -> GET /api/notify -> daemon -> 405
```

## Steps

1. `GET /api/notify` (notify only accepts POST).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPRequest
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/notify"
	return nil
}
```