## Expected

- `resp.DaemonStopped == true`.
- `resp.PIDFileRemoved == true`.
- `resp.TerminatedPID > 0`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if !resp.DaemonStopped {
		t.Fatal("expected daemon_stopped=true after SIGTERM")
	}
	if !resp.PIDFileRemoved {
		t.Fatal("expected pid_file_removed=true after SIGTERM shutdown")
	}
	if resp.TerminatedPID <= 0 {
		t.Fatalf("expected terminated_pid > 0, got %d", resp.TerminatedPID)
	}
	t.Logf("lifecycle/sigterm-stops-daemon OK: pid=%d", resp.TerminatedPID)
}
```