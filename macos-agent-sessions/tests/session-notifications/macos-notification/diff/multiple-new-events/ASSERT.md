## Expected

- `resp.Error == ""`.
- `len(resp.NotifyDirs) == 2`.
- `notify_dirs` contains `/proj/b` and `/proj/c` (order not significant).
- `notify_dirs` does not contain `/proj/existing`.

## Errors

- Missing either new dir fails the test.

```go
import "slices"

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
	if len(resp.NotifyDirs) != 2 {
		t.Fatalf("expected notify_dirs len=2, got %d: %v", len(resp.NotifyDirs), resp.NotifyDirs)
	}
	for _, want := range []string{"/proj/b", "/proj/c"} {
		if !slices.Contains(resp.NotifyDirs, want) {
			t.Fatalf("expected notify_dirs to contain %s, got %v", want, resp.NotifyDirs)
		}
	}
	if slices.Contains(resp.NotifyDirs, "/proj/existing") {
		t.Fatalf("unchanged dir must not notify, got %v", resp.NotifyDirs)
	}
	t.Logf("multiple-new-events OK: notify_dirs=%v", resp.NotifyDirs)
}
```