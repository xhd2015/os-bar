## Expected

- `resp.StateDir == "/tmp/custom-os-bar"`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.StateDir != "/tmp/custom-os-bar" {
		t.Fatalf("expected state_dir=/tmp/custom-os-bar, got %q", resp.StateDir)
	}
	t.Logf("state-dir/env-override OK: state_dir=%q", resp.StateDir)
}
```