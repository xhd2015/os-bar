## Expected

- `resp.ShouldTerminateOnQuit == false`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ShouldTerminateOnQuit {
		t.Fatal("expected should_terminate_on_quit=false for -uiTestingOpenSettings")
	}
	t.Logf("skip-ui-testing OK")
}
```