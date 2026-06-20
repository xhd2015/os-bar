# Scenario

**Feature**: unknown API path returns 404

```
# nonexistent route
harness -> POST /api/wrong -> daemon -> 404
```

## Steps

1. `POST /api/wrong` with empty body.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPRequest
	req.HTTPMethod = "POST"
	req.HTTPPath = "/api/wrong"
	req.HTTPBody = `{}`
	return nil
}
```