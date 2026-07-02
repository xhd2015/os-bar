## Expected

- `resp.ButtonLabel` = `"Restart Daemon (Port: 38271, PID: 12345)"`

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("unexpected error: %s", resp.Error)
	}
	want := "Restart Daemon (Port: 38271, PID: 12345)"
	if resp.ButtonLabel != want {
		t.Fatalf("expected %q, got %q", want, resp.ButtonLabel)
	}
	t.Logf("OK: label = %q", resp.ButtonLabel)
}
```