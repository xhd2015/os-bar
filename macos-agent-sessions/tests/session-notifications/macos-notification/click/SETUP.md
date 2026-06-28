# Scenario

**Feature**: session click handlers (menu bar vs notification)

```
# menu item: execute code <dir> only
menu_item_click(dir) -> executed_command, app_activated=false, window_opened=false

# notification: kool IPC probe then optional code fallback; log openMethod
notification_click(dir) -> kool_attempt?, executed_command, open_method, opened_dir, consumed_dir

# vscode focus: multi-window VS Code; notification uses kool IPC to focus target window
vscode_focus_click(source, dir, frontmost, open_dirs, kool_present_paths, kool_ipc_handled)
  -> focused_vscode_dir, open_method, executed_command
vscode_focus_parity(...) -> menu_focused_vscode_dir, focused_vscode_dir

# kool-only probe (no multi-window): notification_kool_open
notification_kool_open(dir, kool env) -> open_method, kool_attempted, fallback_reason, code_executed
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