# Scenario

**Feature**: No `config.json` exists → default `open_method` is `"vscode"`

## Steps

1. Start daemon with clean temp state dir (no config.json pre-seeded).
2. Send `GET /api/config`.
3. Assert HTTP 200, `open_method` = `"vscode"`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionConfigGet
	return nil
}
```