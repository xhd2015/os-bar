# Scenario

**Feature**: Logs viewer menu stays enabled even when daemon is down

```
# daemon unreachable — viewer menu still clickable
info_error="daemon unreachable" -> menu_label="Logs", menu_enabled=true
```

## Steps

1. Set `req.InfoError` to simulate failed daemon info.
2. Call `logs_viewer_menu_state` via Swift test helper.

## Context

- Window shows error banner when opened with daemon down; menu item is not disabled.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsViewerMenuState
	req.InfoError = "daemon unreachable: connection refused"
	return nil
}
```