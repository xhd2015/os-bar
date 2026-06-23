# Scenario

**Feature**: daemon unreachable → disabled menu with error hint

```
# DaemonClient.info() fails (connection refused, non-200, decode error)
info_error="daemon unreachable" -> menu_label="Open Logs (daemon unreachable)", menu_enabled=false
```

## Steps

1. Set `req.InfoError` to a non-empty error string simulating failed `info()`.
2. Leave `req.StoragePath` empty (no path without daemon).
3. Call `open_logs_menu_state` via Swift test helper.

## Context

- Matches both Help menu and menu-bar dropdown when daemon is down.
- App must not use local/env path fallback.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenLogsMenuState
	req.InfoError = "daemon unreachable: connection refused"
	req.StoragePath = ""
	return nil
}
```