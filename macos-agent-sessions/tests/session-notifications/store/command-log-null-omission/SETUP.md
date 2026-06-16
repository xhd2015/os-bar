## Steps
1. Call `Run(t, req)` with `action: "log_command_test"` and NO command fields set.
2. The test helper creates an entry without a `command` and verifies the `"command"` key is absent from the serialized JSON.
3. The response indicates success via `resp.UnconsumedCount == 1`.

## Context
- This validates that Codable's `encodeIfPresent` / optional default omits the `command` key when the field is `nil`.
- No `log_command` or `log_exit_code` fields are set, so the helper creates a bare `NotifyLogEntry`.
- `resp.Count` carries `durationMs` (which will be 0 since no command was specified in the round-trip test).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "log_command_null_omit"
	req.LogDir = "/Users/test/project-a"
	req.LogEvent = "session.finished"
	// Intentionally leave log_command, log_exit_code, etc. unset
	return nil
}
```
