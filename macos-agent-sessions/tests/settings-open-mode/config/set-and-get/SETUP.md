# Scenario

**Feature**: `POST /api/config {open_method:"iterm2"}` → `GET /api/config` returns iterm2

## Steps

1. Start daemon with clean temp state dir.
2. Send `POST /api/config {"open_method":"iterm2"}`.
3. Verify via `GET /api/config` → `open_method=iterm2`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionSetConfig
	req.OpenMethod = "iterm2"
	return nil
}
```