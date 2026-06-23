## Expected

- `resp.Error == ""`.
- `resp.Body == "b"`.
- `resp.Subtitle == "a"`.
- `resp.UserInfoDir == "/work/a/b"`.

```go
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
	if resp.Body != "b" {
		t.Fatalf("expected body %q, got %q", "b", resp.Body)
	}
	if resp.Subtitle != "a" {
		t.Fatalf("expected subtitle %q, got %q", "a", resp.Subtitle)
	}
	if resp.UserInfoDir != "/work/a/b" {
		t.Fatalf("expected user_info_dir %q, got %q", "/work/a/b", resp.UserInfoDir)
	}
	t.Logf("subtitle-cwd-relative OK: body=%q subtitle=%q", resp.Body, resp.Subtitle)
}
```