# Scenario

**Feature**: log file absent → open state directory in Finder

```
# empty storage_path, no notify-logs.jsonl
storage_path/ (no notify-logs.jsonl)

# plan opens the directory
-> reveal_kind=directory, reveal_path=storage_path
```

## Steps

1. Create isolated empty `storage_path` under `t.TempDir()`.
2. Do **not** create `notify-logs.jsonl`.
3. Set `req.StoragePath` and `req.SeedLogFile = false`.
4. Call `logs_finder_plan` via Swift test helper.

## Context

- Covers fresh daemon state before any log-only notify entries are written.

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
	req.Action = actionLogsFinderPlan
	req.StoragePath = stateDir
	req.SeedLogFile = false
	return nil
}
```