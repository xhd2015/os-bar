## Steps
1. Use an incorrect URL path: `/api/wrong` instead of `/api/notify`.
2. Call `Run(t, req)` with `action: "server_post"`, `http_method: "POST"`, `http_path: "/api/wrong"`.

## Context
- The server only serves the `/api/notify` endpoint.
- Requests to any other path should return HTTP 404 Not Found.
- No event should be stored.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "server_post"
	req.HTTPMethod = "POST"
	req.HTTPPath = "/api/wrong"
	req.HTTPBody = `{"type": "test", "dir": "/Users/test/wrong-path"}`
	req.ContentType = "application/json"
	return nil
}
```
