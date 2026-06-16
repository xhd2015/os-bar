## Expected
- `resp.Count == 1`.
- `resp.UnconsumedCount == 1`.
- `resp.Events[0].Consumed == false`.
- `resp.Events[0].Dir == "/d"`.
- `resp.Error == ""`.

## Errors
- If `count != 1`, the test fails (duplicate created).
- If `consumed != false`, the test fails (dedup didn't reset consumed).
- If `unconsumed_count != 1`, the test fails.

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
		t.Fatalf("dedup failed: expected count=1, got count=%d", resp.Count)
	}
	if resp.UnconsumedCount != 1 {
		t.Fatalf("expected unconsumed_count=1 after dedup reset, got %d", resp.UnconsumedCount)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(resp.Events))
	}

	ev := resp.Events[0]
	if ev.Consumed != false {
		t.Fatalf("expected consumed=false after dedup (was true), got %v", ev.Consumed)
	}
	if ev.Dir != "/d" {
		t.Fatalf("expected dir=/d, got dir=%s", ev.Dir)
	}

	t.Logf("consumed-dedup OK: dedup reset consumed to false, unconsumed_count=%d", resp.UnconsumedCount)
}
```
