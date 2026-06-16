## Expected
- `resp.RelativeTime == "<1m ago"`.
- `resp.Error == ""`.

## Errors
- If `relative_time` is not `"<1m ago"`, the test fails with the actual value.

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

	if resp.RelativeTime != "<1m ago" {
		t.Fatalf("expected relative_time=<1m ago for 30s ago, got %q", resp.RelativeTime)
	}

	t.Logf("sub-1m OK: 30s ago → %q", resp.RelativeTime)
}
```
