## Expected
- `resp.Count == 1`.
- `len(resp.Events) == 1`.
- `resp.Events[0].Dir == "/Users/test/project-a"`.
- `resp.Events[0].ID` is a non-empty string (valid UUID).
- `resp.Events[0].Timestamp` is a non-empty ISO8601 string.
- `resp.Error == ""`.

## Errors
- If `count != 1`, the test fails with the actual count.
- If the event dir does not match, the test fails.
- If `Run` returns an error, the test fails.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("test helper reported error: %s", resp.Error)
	}

	if resp.Count != 1 {
		t.Fatalf("expected count=1, got count=%d", resp.Count)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(resp.Events))
	}

	ev := resp.Events[0]
	if ev.Dir != "/Users/test/project-a" {
		t.Fatalf("expected dir=/Users/test/project-a, got dir=%s", ev.Dir)
	}
	if ev.ID == "" {
		t.Fatal("expected non-empty event ID")
	}
	if ev.Timestamp == "" {
		t.Fatal("expected non-empty timestamp")
	}

	t.Logf("add-event OK: count=%d, dir=%s, id=%s, ts=%s", resp.Count, ev.Dir, ev.ID, ev.Timestamp)
}
```
