## Expected
- `resp.Count == 3`.
- `resp.UnconsumedCount == 2`.
- `resp.Events[0].Dir == "/a"` (newest-first order).
- `resp.Events[1].Dir == "/b"`.
- `resp.Events[2].Dir == "/c"`.
- Events at indices 0 and 2 have `consumed == false`; event at index 1 has `consumed == true`.
- `resp.Error == ""`.

## Errors
- If `unconsumed_count != 2`, the test fails.
- If any event's `consumed` value is wrong, the test fails.

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
	if resp.UnconsumedCount != 2 {
		t.Fatalf("expected unconsumed_count=2 (2 of 3 unconsumed), got %d", resp.UnconsumedCount)
	}
	if len(resp.Events) != 3 {
		t.Fatalf("expected 3 events, got %d", len(resp.Events))
	}

	// Verify newest-first ordering
	expectedDirs := []string{"/a", "/b", "/c"}
	expectedConsumed := []bool{false, true, false}
	for i := 0; i < 3; i++ {
		if resp.Events[i].Dir != expectedDirs[i] {
			t.Fatalf("wrong order at index %d: expected %s, got %s",
				i, expectedDirs[i], resp.Events[i].Dir)
		}
		if resp.Events[i].Consumed != expectedConsumed[i] {
			t.Fatalf("wrong consumed at index %d (dir=%s): expected %v, got %v",
				i, resp.Events[i].Dir, expectedConsumed[i], resp.Events[i].Consumed)
		}
	}

	t.Logf("unconsumed-count OK: 3 events, 2 unconsumed → unconsumed_count=%d", resp.UnconsumedCount)
}
```
