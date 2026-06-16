## Expected
- `resp.RelativeTime == "2h ago"`.
- `resp.Error == ""`.

## Errors
- If `relative_time` is not `"2h ago"`, the test fails with the actual value.

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

	if resp.RelativeTime != "2h ago" {
		t.Fatalf("expected relative_time=2h ago for 2h ago, got %q", resp.RelativeTime)
	}

	t.Logf("exact-hours OK: 2h ago → %q", resp.RelativeTime)
}
```
