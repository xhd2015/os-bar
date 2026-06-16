## Expected
- `resp.Count == 1`.
- `len(resp.Events) == 1`.
- `resp.Events[0].Dir == "/Users/test/project-x"`.
- `resp.Error == ""`.

## Errors
- If `count != 1` (duplicate created), the test fails.
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
		t.Fatalf("dedup failed: expected count=1 after adding same dir twice, got count=%d", resp.Count)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("dedup failed: expected 1 event, got %d", len(resp.Events))
	}
	if resp.Events[0].Dir != "/Users/test/project-x" {
		t.Fatalf("expected dir=/Users/test/project-x, got dir=%s", resp.Events[0].Dir)
	}

	t.Logf("dedup-dir OK: same dir added twice → count=%d, timestamp=%s", resp.Count, resp.Events[0].Timestamp)
}
```
