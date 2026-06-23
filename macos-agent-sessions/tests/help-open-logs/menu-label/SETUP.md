# Scenario

**Feature**: dynamic Open Logs menu label and enabled state

```
# daemon reachable, storage_path returned
info_error="" -> menu_label="Show Logs in Finder", menu_enabled=true

# daemon unreachable / API error
info_error set -> menu_label="Show Logs in Finder (daemon unreachable)", menu_enabled=false
```

## Preconditions

- Tests exercise `open_logs_menu_state` via Swift `TestHelper` (no UI rendering).
- The same label/enabled pair applies to **both** Help menu and menu-bar dropdown.
- Empty `info_error` simulates successful `DaemonClient.info()`.

## Steps

1. Set `req.Action = open_logs_menu_state`.
2. Leaf `Setup` sets `req.InfoError` (empty for success, non-empty for error).
3. Assert on `menu_label` and `menu_enabled`.

## Context

- No keyboard shortcut in v1.
- Label refreshes on app launch and when either menu opens (not asserted here).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenLogsMenuState
	return nil
}
```