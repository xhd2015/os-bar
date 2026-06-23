## Expected

- `resp.Error == ""`.
- `resp.RevealKind == "file"`.
- `resp.RevealPath` ends with `notify-logs.jsonl` and exists on disk.
- `resp.SelectRoot == req.StoragePath` (normalized absolute paths).

## Side Effects

- No real Finder invocation; only pure plan output.

## Errors

- If `Run` returns an error, the test fails.
- Wrong `reveal_kind` or missing `select_root` fails the test.

```go
import (
	"os"
	"path/filepath"
	"strings"
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
	if resp.RevealKind != "file" {
		t.Fatalf("expected reveal_kind=file, got %q", resp.RevealKind)
	}
	wantLog := filepath.Join(req.StoragePath, "notify-logs.jsonl")
	gotPath, _ := filepath.Abs(resp.RevealPath)
	wantPath, _ := filepath.Abs(wantLog)
	if gotPath != wantPath {
		t.Fatalf("reveal_path mismatch: got %q want %q", gotPath, wantPath)
	}
	if _, statErr := os.Stat(gotPath); statErr != nil {
		t.Fatalf("reveal_path does not exist: %v", statErr)
	}
	gotRoot, _ := filepath.Abs(resp.SelectRoot)
	wantRoot, _ := filepath.Abs(req.StoragePath)
	if gotRoot != wantRoot {
		t.Fatalf("select_root mismatch: got %q want %q", gotRoot, wantRoot)
	}
	if !strings.HasSuffix(resp.RevealPath, "notify-logs.jsonl") {
		t.Fatalf("reveal_path should end with notify-logs.jsonl, got %q", resp.RevealPath)
	}
	t.Logf("finder-plan/file-exists OK: reveal_path=%s select_root=%s", resp.RevealPath, resp.SelectRoot)
}
```