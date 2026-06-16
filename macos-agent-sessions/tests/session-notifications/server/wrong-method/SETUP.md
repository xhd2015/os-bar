## Steps
1. Use HTTP method GET instead of POST for the `/api/notify` endpoint.
2. Call `Run(t, req)` with `action: "server_post"`, `http_method: "GET"`, `http_path: "/api/notify"`.

## Context
- The `/api/notify` endpoint only accepts POST requests.
- Any other method (GET, PUT, DELETE, etc.) should return HTTP 405 Method Not Allowed.
- No event should be stored regardless of the body.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "server_post"
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/notify"
	req.HTTPBody = `{"type": "test", "dir": "/Users/test/wrong-method"}`
	req.ContentType = "application/json"
	return nil
}
```
