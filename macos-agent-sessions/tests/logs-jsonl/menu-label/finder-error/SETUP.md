# Scenario

**Feature**: daemon unreachable → disabled Show Logs in Finder

```
# DaemonClient.info() fails
info_error="daemon unreachable" -> menu_label="Show Logs in Finder (daemon unreachable)", menu_enabled=false
```

## Steps

1. Set `req.InfoError` to a non-empty error string.
2. Call `open_logs_menu_state` via Swift test helper.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenLogsMenuState
	req.InfoError = "daemon unreachable: connection refused"
	req.StoragePath = ""
	return nil
}
```