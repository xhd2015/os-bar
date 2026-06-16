## Expected
- `resp.RelativeTime == "5m ago"`.
- `resp.Error == ""`.

## Errors
- If `relative_time` is not `"5m ago"`, the test fails with the actual value.

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

	if resp.RelativeTime != "5m ago" {
		t.Fatalf("expected relative_time=5m ago for 5m ago, got %q", resp.RelativeTime)
	}

	t.Logf("exact-minutes OK: 5m ago → %q", resp.RelativeTime)
}
```
