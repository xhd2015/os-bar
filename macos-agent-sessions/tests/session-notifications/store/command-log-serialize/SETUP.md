# Scenario

**Feature**: command log encode decode round-trip

```
log_command_roundtrip -> decoded fields match
```

## Steps
1. Call `Run(t, req)` with `action: "log_command_test"` and command log fields populated.
2. Capture the `Response` with the encoded JSON and decoded values.
3. Compare decoded values match the original inputs.

## Context
- This leaf validates that a `NotifyLogEntry` with a `command` field survives JSON encode → decode round-trip.
- The test helper creates a `TestNotifyLogEntry` with `CommandLogDetails`, encodes to JSON, decodes, and returns both the raw JSON and the decoded values via response fields.
- `resp.Count` carries `durationMs`, `resp.HTTPStatus` carries `exitCode`, `resp.HTTPBody` carries `stdout`, `resp.RelativeTime` carries `stderr`.
- `resp.UnconsumedCount == 1` on success (magic value).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "log_command_roundtrip"
	req.LogDir = "/Users/test/project-a"
	req.LogEvent = "command.executed"
	req.LogCommand = "code /Users/test/project-a"
	req.LogExitCode = 0
	req.LogStdout = ""
	req.LogStderr = ""
	req.LogDurationMs = 234
	return nil
}
```
