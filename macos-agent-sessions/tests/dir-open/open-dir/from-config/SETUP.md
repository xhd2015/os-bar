# Scenario

**Feature**: Config has `open_method="iterm2"`, request omits `open_method` → uses config value (iterm2)

## Steps

1. First set config to `"iterm2"` via `POST /api/config`.
2. Then send `POST /api/open-dir {"dir":"/tmp"}` (no open_method).
3. Assert `ok=true`, `open_method_used="iterm2"`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenDir
	req.Dir = "/tmp"
	req.OpenMethod = ""  // omit to test config fallback
	req.PreSetConfig = "iterm2"  // seed config before daemon starts
	req.Iterm2Installed = true
	return nil
}
```