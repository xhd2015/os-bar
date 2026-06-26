# Scenario

**Feature**: session click handlers (menu bar vs notification)

```
# menu item: execute code <dir> only
menu_item_click(dir) -> executed_command, app_activated=false, window_opened=false

# notification: activate app first (no window), then execute code <dir>
notification_click(dir) -> app_activated=true, window_opened=false, executed_command, opened_dir, consumed_dir

# vscode focus: multi-window VS Code; click must focus window for target dir
vscode_focus_click(source, dir, frontmost, open_dirs) -> focused_vscode_dir
vscode_focus_parity(dir, frontmost, open_dirs) -> menu_focused_vscode_dir, focused_vscode_dir
```

## Preconditions

- Click handlers mirror `SessionClickHandler` with mocked `activateApp` and `openSessionDir`.
- VS Code focus leaves model `openDir` + `activateVSCodeIfNeeded` with multiple workspace windows.
- No real `code` binary launch; no AppKit calls.

## Steps

- Menu leaf sets `action: "menu_item_click"` with target `dir`.
- Notification leaf sets `action: "notification_click"` with target `dir`.
- VS Code focus leaves set `vscode_frontmost_dir` and `vscode_open_dirs` for multi-window state.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("session click: grouping menu_item_click and notification_click leaves")
	return nil
}
```