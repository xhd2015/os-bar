## Expected

- `resp.DaemonStopped` = true
- `resp.DaemonAlive` = true

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("unexpected error: %s", resp.Error)
	}
	if !resp.DaemonStopped {
		t.Fatal("expected daemon to stop after SIGTERM")
	}
	if !resp.DaemonAlive {
		t.Fatal("expected new daemon to be alive after restart")
	}
	t.Logf("OK: daemon restarted successfully")
}
```