# Scenario

**Feature**: pure Finder reveal plan for Open Logs click handler

```
# given storage_path from daemon info
storage_path + filesystem state -> LogsFinderPlan

# file exists → select notify-logs.json in Finder
seed notify-logs.json -> reveal_kind=file, reveal_path=<log>, select_root=storage_path

# file missing → open storage_path directory
empty dir -> reveal_kind=directory, reveal_path=storage_path
```

## Preconditions

- Tests exercise `logs_finder_plan` via Swift `TestHelper` (no real `NSWorkspace` calls).
- `storage_path` is an isolated temp directory created in leaf `Setup`.
- Log file name is always `notify-logs.json` under `storage_path`.

## Steps

1. Set `req.Action = logs_finder_plan`.
2. Leaf `Setup` creates `storage_path` and optionally seeds the log file.
3. Assert on `reveal_kind`, `reveal_path`, and `select_root`.

## Context

- Production uses `NSWorkspace.shared.selectFile` for file case and `.open(URL)` for directory case.
- `select_root` is only meaningful when `reveal_kind == "file"`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsFinderPlan
	return nil
}
```