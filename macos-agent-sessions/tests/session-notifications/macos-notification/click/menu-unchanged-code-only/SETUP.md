# Scenario

**Feature**: menu bar click never attempts kool even when installed

```
# menu + kool on disk -> code only
vscode_focus_click(menu, dir) -> kool_attempted=false, code command
```

## Steps

1. Simulate all kool candidate paths present and IPC would succeed if called.
2. Run menu-source focus click for `/proj/b`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "vscode_focus_click"
	req.ClickSource = "menu"
	req.Dir = "/proj/b"
	req.VSCodeFrontmostDir = "/proj/a"
	req.VSCodeOpenDirs = []string{"/proj/a", "/proj/b"}
	req.KoolPresentPaths = []string{
		"/usr/bin/kool",
		"/usr/local/bin/kool",
		"/Users/xhd2015/go/bin/kool",
	}
	req.KoolIPCHandled = true
	return nil
}
```