# Scenario

**Feature**: `POST /api/config` with invalid `open_method` → HTTP error

## Steps

1. Start daemon with clean temp state dir.
2. Send `POST /api/config {"open_method":"invalid"}`.
3. Assert HTTP 400 or error response.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionSetConfig
	req.OpenMethod = "invalid"
	return nil
}
```