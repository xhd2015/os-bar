## Expected

- `len(resp.LogEntries) == 3`.
- Entry dirs include `/one`, `/two`, `/three`.
- `notify-logs.jsonl` still exists on disk with 3 lines.

## Side Effects

- No migration; file was already JSONL.

## Errors

- Entry count mismatch or missing dir fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200, got %d body=%s", resp.HTTPStatus, resp.HTTPBody)
	}
	if len(resp.LogEntries) != 3 {
		t.Fatalf("expected 3 log entries, got %d", len(resp.LogEntries))
	}
	dirs := map[string]bool{}
	for _, e := range resp.LogEntries {
		dirs[e.Dir] = true
	}
	for _, want := range []string{"/one", "/two", "/three"} {
		if !dirs[want] {
			t.Fatalf("missing dir %q in loaded entries", want)
		}
	}
	lines := readJSONLLines(t, logsJSONLPath(resp.StateDir))
	if len(lines) != 3 {
		t.Fatalf("expected 3 lines on disk, got %d", len(lines))
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("load/reads-jsonl OK: %d entries", len(resp.LogEntries))
}
```