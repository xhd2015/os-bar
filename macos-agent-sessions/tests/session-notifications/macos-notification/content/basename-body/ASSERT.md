## Expected

- `resp.Error == ""`.
- `resp.Title == "Agent session finished"`.
- `resp.Body == "my-app"`.
- `resp.UserInfoDir == "/Users/me/work/my-app"`.

## Errors

- Wrong body or title fails the test.

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
	if resp.Title != "Agent session finished" {
		t.Fatalf("expected title %q, got %q", "Agent session finished", resp.Title)
	}
	if resp.Body != "my-app" {
		t.Fatalf("expected body %q, got %q", "my-app", resp.Body)
	}
	if resp.UserInfoDir != "/Users/me/work/my-app" {
		t.Fatalf("expected user_info_dir %q, got %q", "/Users/me/work/my-app", resp.UserInfoDir)
	}
	t.Logf("basename-body OK: title=%q body=%q", resp.Title, resp.Body)
}
```