# Scenario

**Feature**: type field accepted but not stored

```
POST with type -> dir stored
```

## Steps
1. Construct a JSON request body with an explicit `type` field: `{"type": "cursor", "dir": "/Users/test/cursor-project"}`.
2. Call `Run(t, req)` with `action: "server_post"` and the body.

## Context
- The `type` field in the request is accepted (parsed) but ignored — it is not stored in the event.
- This leaf verifies that requests with any `type` value are accepted and that `type` does not affect storage.
- The event stored should only contain `id`, `dir`, and `timestamp` (no `type` field).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "server_post"
	req.HTTPMethod = "POST"
	req.HTTPPath = "/api/notify"
	req.HTTPBody = `{"type": "cursor", "dir": "/Users/test/cursor-project"}`
	req.ContentType = "application/json"
	return nil
}
```
