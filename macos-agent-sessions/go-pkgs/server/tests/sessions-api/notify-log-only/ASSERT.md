## Expected

- After list step: `len(resp.Events) == 0`.
- After logs step: `len(resp.LogEntries) == 1`.
- `resp.LogEntries[0].Dir == "/proj"`.
- Log entry `source` is not `"notify"` (or absent).

## Side Effects

- `events.json` remains empty.
- `notify-logs.jsonl` gains one entry (JSONL line on disk).

## Errors

- Any session event in list fails the test.
- Zero log entries fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 0 {
		t.Fatalf("expected empty event list, got %d events", len(resp.Events))
	}
	if len(resp.LogEntries) != 1 {
		t.Fatalf("expected 1 log entry, got %d", len(resp.LogEntries))
	}
	if resp.LogEntries[0].Dir != "/proj" {
		t.Fatalf("expected log dir=/proj, got %q", resp.LogEntries[0].Dir)
	}
	if resp.LogEntries[0].Source == "notify" {
		t.Fatalf("log-only notify should not have source=notify, got %q", resp.LogEntries[0].Source)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("sessions-api/notify-log-only OK: logs=%d events=%d", len(resp.LogEntries), len(resp.Events))
}
```