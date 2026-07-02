# Scenario

**Feature**: `POST /api/open-dir {dir:"/tmp", open_method:"iterm2"}` → `ok=true, open_method_used="iterm2"`

## Steps

1. Set env `KOOL_ITERM2_INSTALLED=1` and `KOOL_ITERM2_SCRIPT_OUT=<tempFile>`.
2. Start daemon with those env vars set.
3. Send `POST /api/open-dir {"dir":"/tmp", "open_method":"iterm2"}`.
4. Assert `ok=true`, `open_method_used="iterm2"`.
5. Assert AppleScript was written to the script out path.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenDir
	req.Dir = "/tmp"
	req.OpenMethod = "iterm2"
	req.Iterm2Installed = true
	return nil
}
```