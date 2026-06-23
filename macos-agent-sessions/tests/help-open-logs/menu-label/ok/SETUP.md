# Scenario

**Feature**: successful daemon info → enabled Open Logs menu item

```
# DaemonClient.info() succeeds
info_error="" -> menu_label="Open Logs", menu_enabled=true
```

## Steps

1. Set `req.InfoError = ""` (no error).
2. Optionally set `req.StoragePath` to a non-empty temp path (helper may ignore when no error).
3. Call `open_logs_menu_state` via Swift test helper.

## Context

- User can click Open Logs in Help menu or menu-bar dropdown.

```go
import (
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenLogsMenuState
	req.InfoError = ""
	req.StoragePath = filepath.Join(t.TempDir(), "state")
	return nil
}
```