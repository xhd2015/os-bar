## Expected

- `resp.QuitTargetKind == "spawned"`.
- `resp.QuitTargetPID == 1234`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	if resp.QuitTargetKind != "spawned" {
		t.Fatalf("expected quit_target_kind=spawned, got %q", resp.QuitTargetKind)
	}
	if resp.QuitTargetPID != 1234 {
		t.Fatalf("expected quit_target_pid=1234, got %d", resp.QuitTargetPID)
	}
	t.Logf("plan/spawned-priority OK: kind=%s pid=%d", resp.QuitTargetKind, resp.QuitTargetPID)
}
```