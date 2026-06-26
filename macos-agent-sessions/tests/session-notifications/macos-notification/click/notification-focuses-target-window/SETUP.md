# Scenario

**Feature**: notification click focuses the VS Code window for the target directory

```
# VS Code has /proj/a frontmost; user clicks notification for /proj/b
vscode_focus_click(notification, target=/proj/b, frontmost=/proj/a, open=[/proj/a,/proj/b])
  -> focused_vscode_dir=/proj/b
```

## Preconditions

- VS Code has two workspace windows open: `/proj/a` (frontmost) and `/proj/b` (background).
- Simulator mirrors `SessionClickHandler` + `openDir` + `activateVSCodeIfNeeded` ordering.
- No real `code` binary launch; no AppKit calls.

## Steps

1. Set `action` to `vscode_focus_click`, `click_source` to `notification`.
2. Set `dir` to `/proj/b`, `vscode_frontmost_dir` to `/proj/a`.
3. Set `vscode_open_dirs` to `["/proj/a", "/proj/b"]`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "vscode_focus_click"
	req.ClickSource = "notification"
	req.Dir = "/proj/b"
	req.VSCodeFrontmostDir = "/proj/a"
	req.VSCodeOpenDirs = []string{"/proj/a", "/proj/b"}
	return nil
}
```