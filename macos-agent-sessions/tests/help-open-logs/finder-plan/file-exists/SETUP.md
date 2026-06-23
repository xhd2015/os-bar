# Scenario

**Feature**: log file present → select file in Finder

```
# seed notify-logs.jsonl under storage_path
storage_path/notify-logs.jsonl exists

# plan selects the log file rooted at storage_path
-> reveal_kind=file, reveal_path=<log>, select_root=storage_path
```

## Steps

1. Create isolated `storage_path` under `t.TempDir()`.
2. Write `notify-logs.jsonl` with one minimal JSONL line (empty object or sample entry).
3. Set `req.StoragePath` and `req.SeedLogFile = true`.
4. Call `logs_finder_plan` via Swift test helper.

## Context

- Matches the common case after the daemon has written notification logs.

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	stateDir := filepath.Join(t.TempDir(), "state")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return err
	}
	logPath := filepath.Join(stateDir, "notify-logs.jsonl")
	if err := os.WriteFile(logPath, []byte("{}\n"), 0644); err != nil {
		return err
	}
	req.Action = actionLogsFinderPlan
	req.StoragePath = stateDir
	req.SeedLogFile = true
	return nil
}
```