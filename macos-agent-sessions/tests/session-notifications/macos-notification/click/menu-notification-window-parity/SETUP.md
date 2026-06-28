# Scenario

**Feature**: menu and notification clicks focus the same VS Code window

```
# same multi-window state; menu click for /proj/b -> focused_vscode_dir=/proj/b
# notification click for /proj/b -> focused_vscode_dir=/proj/b (must match menu)
```

## Preconditions

- VS Code has `/proj/a` frontmost and `/proj/b` open in background.
- Menu click is the known-good reference path.
- Notification click must produce identical window focus, not just foreground the app.

## Steps

1. Run `vscode_focus_click` with `click_source=menu` for `/proj/b`.
2. Run `vscode_focus_click` with `click_source=notification` for `/proj/b`.
3. Compare `focused_vscode_dir` from both responses (encoded in single helper call via parity action).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "vscode_focus_parity"
	req.Dir = "/proj/b"
	req.VSCodeFrontmostDir = "/proj/a"
	req.VSCodeOpenDirs = []string{"/proj/a", "/proj/b"}
	req.KoolPresentPaths = []string{"/usr/local/bin/kool"}
	req.KoolIPCHandled = true
	return nil
}
```