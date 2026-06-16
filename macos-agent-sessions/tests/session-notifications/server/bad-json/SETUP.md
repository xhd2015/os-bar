## Steps
1. Construct an unparseable request body: `this is not json`.
2. Call `Run(t, req)` with `action: "server_post"`, `http_method: "POST"`, `http_path: "/api/notify"`, `http_body: "this is not json"`, and `content_type: "application/json"`.

## Context
- The server should reject requests whose body cannot be parsed as JSON with HTTP 400.
- The store should remain unchanged (count=0).
- The Content-Type header is `application/json` but the body is not valid JSON.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "server_post"
	req.HTTPMethod = "POST"
	req.HTTPPath = "/api/notify"
	req.HTTPBody = `this is not json`
	req.ContentType = "application/json"
	return nil
}
```
