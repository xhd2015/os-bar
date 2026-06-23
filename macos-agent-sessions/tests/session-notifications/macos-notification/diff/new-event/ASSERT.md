## Expected

- `resp.Error == ""`.
- `len(resp.NotifyDirs) == 1`.
- `resp.NotifyDirs[0] == "/proj/a"`.

## Side Effects

- No real macOS notification is posted; only diff logic is evaluated.

## Errors

- If `Run` returns an error, the test fails.
- If `notify_dirs` is empty or does not contain `/proj/a`, the test fails.

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
	if len(resp.NotifyDirs) != 1 {
		t.Fatalf("expected notify_dirs len=1, got %d: %v", len(resp.NotifyDirs), resp.NotifyDirs)
	}
	if resp.NotifyDirs[0] != "/proj/a" {
		t.Fatalf("expected notify_dirs=[/proj/a], got %v", resp.NotifyDirs)
	}
	t.Logf("new-event OK: notify_dirs=%v", resp.NotifyDirs)
}
```