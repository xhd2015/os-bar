## Expected

- `resp.Error == ""`.
- `resp.RevealKind == "directory"`.
- `resp.RevealPath` equals `req.StoragePath` (normalized absolute paths).
- `resp.SelectRoot == ""` (not used for directory reveal).

## Side Effects

- No real Finder invocation; only pure plan output.

## Errors

- If `Run` returns an error, the test fails.
- `reveal_kind=file` or non-empty `select_root` fails the test.

```go
import (
	"os"
	"path/filepath"
)

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
	if resp.RevealKind != "directory" {
		t.Fatalf("expected reveal_kind=directory, got %q", resp.RevealKind)
	}
	gotPath, _ := filepath.Abs(resp.RevealPath)
	wantPath, _ := filepath.Abs(req.StoragePath)
	if gotPath != wantPath {
		t.Fatalf("reveal_path mismatch: got %q want %q", gotPath, wantPath)
	}
	info, statErr := os.Stat(gotPath)
	if statErr != nil {
		t.Fatalf("reveal_path does not exist: %v", statErr)
	}
	if !info.IsDir() {
		t.Fatalf("reveal_path must be a directory, got mode %v", info.Mode())
	}
	if resp.SelectRoot != "" {
		t.Fatalf("expected empty select_root for directory reveal, got %q", resp.SelectRoot)
	}
	t.Logf("finder-plan/file-missing OK: reveal_path=%s", resp.RevealPath)
}
```