# Scenario

**Feature**: valid POST /api/notify

```
POST {dir} -> 200 ok + event stored
```

## Steps
1. Construct a valid JSON request body: `{"type": "test", "dir": "/Users/test/server-project"}`.
2. Call `Run(t, req)` with `action: "server_post"`, `http_method: "POST"`, `http_path: "/api/notify"`, `http_body`, and `content_type: "application/json"`.
3. The test helper starts a server, sends the POST request, and returns the HTTP status, body, and store events.

## Context
- A valid POST to `/api/notify` with correct JSON should:
  - Return HTTP 200.
  - Return body `{"ok": true}`.
  - Store the event with the given dir.
  - The `type` field is parsed but not stored.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "server_post"
	req.HTTPMethod = "POST"
	req.HTTPPath = "/api/notify"
	req.HTTPBody = `{"type": "test", "dir": "/Users/test/server-project"}`
	req.ContentType = "application/json"
	return nil
}
```
