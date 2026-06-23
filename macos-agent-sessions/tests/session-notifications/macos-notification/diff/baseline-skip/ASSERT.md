## Expected

- `resp.Error == ""`.
- `len(resp.NotifyDirs) == 0` even though current has multiple unconsumed events.

## Errors

- Non-empty `notify_dirs` on baseline would notify stale events at app launch.

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
	if len(resp.NotifyDirs) != 0 {
		t.Fatalf("expected empty notify_dirs on baseline poll, got %v", resp.NotifyDirs)
	}
	t.Log("baseline-skip OK: startup baseline suppressed notifications")
}
```