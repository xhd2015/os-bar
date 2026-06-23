# Scenario

**Feature**: missing dir returns 400

```
POST without dir -> 400
```

## Steps
1. Construct a JSON body that lacks the `dir` field: `{"type": "test"}`.
2. Call `Run(t, req)` with `action: "server_post"`, `http_method: "POST"`, `http_path: "/api/notify"`, and `http_body: {"type": "test"}`.

## Context
- The server must reject requests where the `dir` field is missing with HTTP 400.
- This leaf tests the missing case. The empty-string case (`"dir": ""`) should also return 400 per the requirement; the implementer should ensure both are handled.
- No event should be stored (count=0).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "server_post"
	req.HTTPMethod = "POST"
	req.HTTPPath = "/api/notify"
	req.HTTPBody = `{"type": "test"}`
	req.ContentType = "application/json"
	return nil
}
```
