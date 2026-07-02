# Scenario

**Feature**: `POST /api/open-dir {dir:"/tmp", open_method:"vscode"}` → `ok=true, open_method_used="vscode"`

## Steps

1. Start daemon with mock code binary.
2. Send `POST /api/open-dir {"dir":"/tmp", "open_method":"vscode"}`.
3. Assert `ok=true`, `open_method_used="vscode"`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenDir
	req.Dir = "/tmp"
	req.OpenMethod = "vscode"
	return nil
}
```