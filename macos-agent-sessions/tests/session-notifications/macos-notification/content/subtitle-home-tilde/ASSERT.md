## Expected

- `resp.Error == ""`.
- `resp.Title == "Agent session finished"`.
- `resp.Body == "foo"`.
- `resp.Subtitle == "~/Projects"`.
- `resp.UserInfoDir == "/Users/me/Projects/foo"`.

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
	if resp.Body != "foo" {
		t.Fatalf("expected body %q, got %q", "foo", resp.Body)
	}
	if resp.Subtitle != "~/Projects" {
		t.Fatalf("expected subtitle %q, got %q", "~/Projects", resp.Subtitle)
	}
	if resp.UserInfoDir != "/Users/me/Projects/foo" {
		t.Fatalf("expected user_info_dir %q, got %q", "/Users/me/Projects/foo", resp.UserInfoDir)
	}
	t.Logf("subtitle-home-tilde OK: body=%q subtitle=%q", resp.Body, resp.Subtitle)
}
```