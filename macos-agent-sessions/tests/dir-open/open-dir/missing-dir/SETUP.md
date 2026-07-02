# Scenario

**Feature**: `POST /api/open-dir {}` (no dir) → HTTP 400 error

## Steps

1. Start daemon.
2. Send `POST /api/open-dir {}` (empty body).
3. Assert HTTP 400.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenDir
	req.Dir = ""
	req.OpenMethod = ""
	return nil
}
```