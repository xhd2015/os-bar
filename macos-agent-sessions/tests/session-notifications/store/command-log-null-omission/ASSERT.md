## Expected
- `resp.Error` is empty.
- `resp.UnconsumedCount == 1` (success indicator).
- The test helper has already verified that the JSON does NOT contain `"command"` key (it sets `resp.Error` if it does, so `resp.Error == ""` implies the check passed).

## Errors
- If `resp.Error` is non-empty, the entry without command incorrectly serialized the `"command"` key.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("null-omission check failed: %s", resp.Error)
	}

	// Magic success indicator
	if resp.UnconsumedCount != 1 {
		t.Fatalf("expected unconsumed_count=1 (success), got %d", resp.UnconsumedCount)
	}

	t.Logf("command-log-null-omission OK: 'command' key correctly absent when nil")
}
```
