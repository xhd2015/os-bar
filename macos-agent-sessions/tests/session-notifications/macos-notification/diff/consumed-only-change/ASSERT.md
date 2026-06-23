## Expected

- `resp.Error == ""`.
- `len(resp.NotifyDirs) == 0`.

## Errors

- Notification on consumed-only change would spam after user dismisses via menu.

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
		t.Fatalf("expected empty notify_dirs when only consumed changed, got %v", resp.NotifyDirs)
	}
	t.Log("consumed-only-change OK: no notification")
}
```