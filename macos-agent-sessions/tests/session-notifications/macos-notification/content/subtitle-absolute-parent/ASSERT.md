## Expected

- `resp.Error == ""`.
- `resp.Body == "my-app"`.
- `resp.Subtitle == "/opt/projects"`.
- `resp.UserInfoDir == "/opt/projects/my-app"`.

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
	if resp.Body != "my-app" {
		t.Fatalf("expected body %q, got %q", "my-app", resp.Body)
	}
	if resp.Subtitle != "/opt/projects" {
		t.Fatalf("expected subtitle %q, got %q", "/opt/projects", resp.Subtitle)
	}
	if resp.UserInfoDir != "/opt/projects/my-app" {
		t.Fatalf("expected user_info_dir %q, got %q", "/opt/projects/my-app", resp.UserInfoDir)
	}
	t.Logf("subtitle-absolute-parent OK: subtitle=%q", resp.Subtitle)
}
```