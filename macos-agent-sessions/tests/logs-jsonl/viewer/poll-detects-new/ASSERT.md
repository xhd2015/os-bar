## Expected

- `resp.Error == ""`.
- `resp.PollEntryCounts == [1, 2]` (one count per simulated poll).
- `resp.DetectedNew == true` (second poll saw more entries than first).

## Side Effects

- Simulates `LogsViewModel` refresh without opening the real window.

## Errors

- Counts not `[1, 2]` or `detected_new=false` fails the test.

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
	if len(resp.PollEntryCounts) != 2 {
		t.Fatalf("expected 2 poll counts, got %v", resp.PollEntryCounts)
	}
	if resp.PollEntryCounts[0] != 1 || resp.PollEntryCounts[1] != 2 {
		t.Fatalf("expected poll counts [1, 2], got %v", resp.PollEntryCounts)
	}
	if !resp.DetectedNew {
		t.Fatal("expected detected_new=true when entry count increases 1→2")
	}
	t.Logf("viewer/poll-detects-new OK: counts=%v detected_new=%v", resp.PollEntryCounts, resp.DetectedNew)
}
```