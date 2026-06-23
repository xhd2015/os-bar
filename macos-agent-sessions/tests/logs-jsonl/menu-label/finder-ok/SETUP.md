# Scenario

**Feature**: successful daemon info → enabled Show Logs in Finder

```
# DaemonClient.info() succeeds
info_error="" -> menu_label="Show Logs in Finder", menu_enabled=true
```

## Steps

1. Set `req.InfoError = ""`.
2. Call `open_logs_menu_state` via Swift test helper.

```go
import "path/filepath"

func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenLogsMenuState
	req.InfoError = ""
	req.StoragePath = filepath.Join(t.TempDir(), "state")
	return nil
}
```