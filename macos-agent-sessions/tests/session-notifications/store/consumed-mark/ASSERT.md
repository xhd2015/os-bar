## Expected
- `resp.Count == 1`.
- `resp.UnconsumedCount == 0`.
- `resp.Events[0].Consumed == true`.
- `resp.Events[0].Dir == "/m"`.
- `resp.Error == ""`.

## Errors
- If `consumed != true`, the test fails (mark didn't work).
- If `unconsumed_count != 0`, the test fails.

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
	if resp.UnconsumedCount != 0 {
		t.Fatalf("expected unconsumed_count=0 after mark, got %d", resp.UnconsumedCount)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(resp.Events))
	}

	ev := resp.Events[0]
	if ev.Consumed != true {
		t.Fatalf("expected consumed=true after markConsumed, got %v", ev.Consumed)
	}
	if ev.Dir != "/m" {
		t.Fatalf("expected dir=/m, got dir=%s", ev.Dir)
	}

	t.Logf("consumed-mark OK: markConsumed set consumed=true, unconsumed_count=%d", resp.UnconsumedCount)
}
```
