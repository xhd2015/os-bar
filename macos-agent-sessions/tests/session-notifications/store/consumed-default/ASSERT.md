## Expected
- `resp.Count == 1`.
- `resp.UnconsumedCount == 1`.
- `len(resp.Events) == 1`.
- `resp.Events[0].Consumed == false`.
- `resp.Events[0].Dir == "/a"`.
- `resp.Error == ""`.

## Errors
- If `unconsumed_count != 1`, the test fails.
- If `events[0].consumed != false`, the test fails.
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
	if resp.UnconsumedCount != 1 {
		t.Fatalf("expected unconsumed_count=1, got %d", resp.UnconsumedCount)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(resp.Events))
	}

	ev := resp.Events[0]
	if ev.Consumed != false {
		t.Fatalf("expected consumed=false for new event, got %v", ev.Consumed)
	}
	if ev.Dir != "/a" {
		t.Fatalf("expected dir=/a, got dir=%s", ev.Dir)
	}

	t.Logf("consumed-default OK: count=%d, unconsumed=%d, consumed=%v", resp.Count, resp.UnconsumedCount, ev.Consumed)
}
```
