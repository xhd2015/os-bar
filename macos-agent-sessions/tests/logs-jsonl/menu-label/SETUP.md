# Scenario

**Feature**: dynamic menu labels for Finder and Logs viewer items

```
# Finder menu (OpenLogsMenuState) — daemon reachable
info_error="" -> "Show Logs in Finder", enabled=true

# Finder menu — daemon unreachable
info_error set -> "Show Logs in Finder (daemon unreachable)", disabled

# Logs viewer menu — always enabled
info_error set or "" -> "Logs", enabled=true
```

## Preconditions

- Tests exercise Swift `TestHelper` (no UI rendering).
- Finder labels use `open_logs_menu_state` → `OpenLogsMenuState.menuState`.
- Viewer label uses `logs_viewer_menu_state` → `LogsViewerMenuState` (or equivalent).
- Same label/enabled pair applies to **both** Help menu and menu-bar dropdown.

## Steps

1. Set `req.Action` per leaf (`open_logs_menu_state` or `logs_viewer_menu_state`).
2. Leaf `Setup` sets `req.InfoError`.
3. Assert on `menu_label` and `menu_enabled`.

## Context

- Finder item renamed from "Open Logs" to "Show Logs in Finder".
- Logs viewer is a **separate** menu item above Settings.

```go
func Setup(t *testing.T, req *Request) error {
	if req.Action == "" {
		req.Action = actionOpenLogsMenuState
	}
	return nil
}
```