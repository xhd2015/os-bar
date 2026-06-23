## Expected

- `resp.Error == ""`.
- `len(resp.NotifyDirs) == 1`.
- `resp.NotifyDirs[0] == "/proj/a"`.

## Errors

- Empty `notify_dirs` means dedup bump failed to trigger re-notification.

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
	if len(resp.NotifyDirs) != 1 || resp.NotifyDirs[0] != "/proj/a" {
		t.Fatalf("expected notify_dirs=[/proj/a], got %v", resp.NotifyDirs)
	}
	t.Logf("dedup-bump OK: notify_dirs=%v", resp.NotifyDirs)
}
```