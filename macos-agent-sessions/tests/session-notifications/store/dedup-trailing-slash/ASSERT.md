## Expected

- `resp.Error == ""`.
- `resp.Count == 1`.
- `len(resp.Events) == 1`.
- `resp.Events[0].Dir == "/Users/xhd2015/Projects/xhd2015/os-bar"` (canonical, no trailing slash).

## Side Effects

- Menu dropdown must not show two rows with basename `os-bar` for the same project.

## Errors

- `count == 2` means trailing-slash paths were not normalized before dedup.

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
		t.Fatalf("dedup failed: expected count=1 for trailing-slash variants, got count=%d events=%d",
			resp.Count, len(resp.Events))
	}
	if len(resp.Events) != 1 {
		t.Fatalf("dedup failed: expected 1 event, got %d", len(resp.Events))
	}
	wantDir := "/Users/xhd2015/Projects/xhd2015/os-bar"
	if resp.Events[0].Dir != wantDir {
		t.Fatalf("expected canonical dir=%q, got %q", wantDir, resp.Events[0].Dir)
	}
	t.Logf("dedup-trailing-slash OK: count=%d dir=%s", resp.Count, resp.Events[0].Dir)
}
```