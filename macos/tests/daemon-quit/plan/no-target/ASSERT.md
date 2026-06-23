## Expected

- `resp.QuitTargetKind == "none"`.
- `resp.QuitTargetPID == 0`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	if resp.QuitTargetKind != "none" {
		t.Fatalf("expected quit_target_kind=none, got %q", resp.QuitTargetKind)
	}
	if resp.QuitTargetPID != 0 {
		t.Fatalf("expected quit_target_pid=0, got %d", resp.QuitTargetPID)
	}
	t.Logf("plan/no-target OK")
}
```