# Scenario

**Feature**: Config has `open_method="iterm2"`, request has `open_method="vscode"` → explicit overrides config

## Steps

1. First set config to `"iterm2"` via `POST /api/config`.
2. Then send `POST /api/open-dir {"dir":"/tmp", "open_method":"vscode"}`.
3. Assert `ok=true`, `open_method_used="vscode"` (explicit override).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenDir
	req.Dir = "/tmp"
	req.OpenMethod = "vscode"
	req.PreSetConfig = "iterm2"  // config says iterm2, but explicit overrides
	return nil
}
```