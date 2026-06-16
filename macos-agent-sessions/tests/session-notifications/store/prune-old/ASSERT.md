## Expected
- `resp.Count == 0`.
- `len(resp.Events) == 0`.
- `resp.Error == ""`.

## Errors
- If `count > 0` (event not pruned), the test fails.
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

	if resp.Count != 0 {
		t.Fatalf("prune failed: expected count=0 after pruning 8-day-old event, got count=%d", resp.Count)
	}
	if len(resp.Events) != 0 {
		t.Fatalf("prune failed: expected 0 events after pruning, got %d: %+v", len(resp.Events), resp.Events)
	}

	t.Logf("prune-old OK: 8-day-old event pruned, count=%d", resp.Count)
}
```
