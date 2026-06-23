# Scenario

**Feature**: Logs viewer window formatting, command details, JSON prettify, and poll detection (pure logic)

```
# format one log entry for list row
NotifyLogEntry -> display line with timestamp, source, dir basename

# format command.executed detail block
command.executed + CommandLogDetails -> 5 detail lines (or empty for other events)

# prettify entry for raw JSON sheet
NotifyLogEntry -> pretty_json (indented, sorted keys)

# poll detects new entries between cycles
poll 1: 1 entry -> poll 2: 2 entries -> detected_new=true
```

## Preconditions

- Tests exercise viewer helper actions via Swift `TestHelper`:
  - `logs_viewer_format_entry`
  - `logs_viewer_format_command_details`
  - `logs_viewer_prettify_entry`
  - `logs_viewer_poll_detects_new`
- No real window, JSON sheet, or 2s timer; helper mirrors `LogsViewModel` / formatter logic.
- RED until `TestHelper.swift` implements command-details and prettify actions.

## Steps

1. Set `req.Action` to the viewer helper action.
2. Leaf `Setup` supplies `log_entry` (with optional `command` struct) or `poll_sequence`.
3. Assert on `display_line`, `detail_lines`, `pretty_json`, `poll_entry_counts`, `detected_new`.

## Context

- Production window uses `accessibilityIdentifier`: `logs-window`, `logs-entry-json-button`, `logs-entry-json-sheet`.
- Command detail labels: `command:`, `exit code:`, `duration:`, `stdout:`, `stderr:`; empty I/O → `(empty)`.
- Poll interval in app: 2 seconds (not wall-clock asserted here).

```go
func Setup(t *testing.T, req *Request) error {
	if req.Action == "" {
		req.Action = actionLogsViewerFormatEntry
	}
	return nil
}
```