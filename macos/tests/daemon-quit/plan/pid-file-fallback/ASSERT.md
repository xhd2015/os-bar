## Expected

- `resp.QuitTargetKind == "pid_file"`.
- `resp.QuitTargetPID == 4242`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	if resp.QuitTargetKind != "pid_file" {
		t.Fatalf("expected quit_target_kind=pid_file, got %q", resp.QuitTargetKind)
	}
	if resp.QuitTargetPID != 4242 {
		t.Fatalf("expected quit_target_pid=4242, got %d", resp.QuitTargetPID)
	}
	t.Logf("plan/pid-file-fallback OK: kind=%s pid=%d", resp.QuitTargetKind, resp.QuitTargetPID)
}
```