# Scenario

**Feature**: `POST /api/config {open_method:"iterm2"}` → `GET /api/config` returns `"iterm2"`

## Steps

1. Start daemon with clean temp state dir.
2. Send `POST /api/config {"open_method":"iterm2"}`.
3. Send `GET /api/config`.
4. Assert `open_method` = `"iterm2"`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionConfigSet
	req.OpenMethod = "iterm2"
	return nil
}
```