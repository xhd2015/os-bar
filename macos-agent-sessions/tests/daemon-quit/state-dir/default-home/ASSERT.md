## Expected

- `resp.StateDir == "/Users/tester/.os-bar/agent-sessions"`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	want := "/Users/tester/.os-bar/agent-sessions"
	if resp.StateDir != want {
		t.Fatalf("expected state_dir=%q, got %q", want, resp.StateDir)
	}
	t.Logf("state-dir/default-home OK: state_dir=%q", resp.StateDir)
}
```