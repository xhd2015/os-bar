# Scenario

**Feature**: Fresh daemon → `GET /api/config` returns `open_method=vscode`

## Steps

1. Start daemon with clean temp state dir.
2. Send `GET /api/config`.
3. Assert `open_method=vscode`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionGetConfig
	return nil
}
```