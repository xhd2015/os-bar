## Expected

- `resp.ButtonLabel` = `"Restart Daemon (Port: -, PID: -)"`

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("unexpected error: %s", resp.Error)
	}
	want := "Restart Daemon (Port: -, PID: -)"
	if resp.ButtonLabel != want {
		t.Fatalf("expected %q, got %q", want, resp.ButtonLabel)
	}
	t.Logf("OK: label = %q", resp.ButtonLabel)
}
```