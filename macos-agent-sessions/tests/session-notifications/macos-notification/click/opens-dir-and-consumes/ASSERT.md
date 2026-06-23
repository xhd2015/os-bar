## Expected

- `resp.Error == ""`.
- `resp.OpenedDir == "/proj/x"`.
- `resp.ConsumedDir == "/proj/x"`.

## Side Effects

- Test helper records open+consume intent without launching real `code` binary.

## Errors

- Mismatched opened/consumed dirs indicate broken click handler wiring.

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
	if resp.OpenedDir != "/proj/x" {
		t.Fatalf("expected opened_dir %q, got %q", "/proj/x", resp.OpenedDir)
	}
	if resp.ConsumedDir != "/proj/x" {
		t.Fatalf("expected consumed_dir %q, got %q", "/proj/x", resp.ConsumedDir)
	}
	t.Logf("opens-dir-and-consumes OK: opened=%s consumed=%s", resp.OpenedDir, resp.ConsumedDir)
}
```