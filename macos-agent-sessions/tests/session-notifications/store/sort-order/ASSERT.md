## Expected
- `resp.Count == 3`.
- `len(resp.Events) == 3`.
- `resp.Events[0].Dir == "/Users/test/newest-project"` (newest first — the just-added event).
- `resp.Events[1].Dir == "/Users/test/newer-project"` (second newest — T-5min).
- `resp.Events[2].Dir == "/Users/test/older-project"` (oldest — T-10min).
- `resp.Error == ""`.

## Errors
- If `count != 3`, the test fails.
- If any event is in the wrong position, the test fails with the actual order.

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

	if resp.Count != 3 {
		t.Fatalf("expected count=3, got count=%d", resp.Count)
	}
	if len(resp.Events) != 3 {
		t.Fatalf("expected 3 events, got %d", len(resp.Events))
	}

	expectedOrder := []string{
		"/Users/test/newest-project",
		"/Users/test/newer-project",
		"/Users/test/older-project",
	}
	for i, expectedDir := range expectedOrder {
		actualDir := resp.Events[i].Dir
		if actualDir != expectedDir {
			t.Fatalf("sort-order wrong at index %d: expected %s, got %s; full order: %v",
				i, expectedDir, actualDir, dirNames(resp.Events))
		}
	}

	t.Logf("sort-order OK: newest-first confirmed (newest, newer, older)")
}

func dirNames(events []SessionEvent) []string {
	names := make([]string, len(events))
	for i, ev := range events {
		names[i] = ev.Dir
	}
	return names
}
```
