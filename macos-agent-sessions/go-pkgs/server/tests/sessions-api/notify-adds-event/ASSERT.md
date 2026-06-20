## Expected

- Notify step returns HTTP 200.
- `len(resp.Events) == 1`.
- `resp.Events[0].Dir == "/proj"`.
- `resp.Events[0].Consumed == false`.
- `resp.Events[0].ID` is non-empty.
- `resp.Events[0].Timestamp` is non-empty ISO8601.

## Side Effects

- `events.json` under isolated `resp.StateDir` contains one event.
- `notify-logs.json` also receives a log entry.

## Errors

- Non-200 notify status fails the test.
- Empty list after notify fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d (body=%q)", len(resp.Events), resp.HTTPBody)
	}
	ev := resp.Events[0]
	if ev.Dir != "/proj" {
		t.Fatalf("expected dir=/proj, got %q", ev.Dir)
	}
	if ev.Consumed {
		t.Fatal("expected consumed=false for new notify event")
	}
	if ev.ID == "" {
		t.Fatal("expected non-empty event id")
	}
	if ev.Timestamp == "" {
		t.Fatal("expected non-empty timestamp")
	}
	if _, err := parseTimeISO(ev.Timestamp); err != nil {
		t.Fatalf("invalid timestamp %q: %v", ev.Timestamp, err)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("sessions-api/notify-adds-event OK: id=%s", ev.ID)
}
```