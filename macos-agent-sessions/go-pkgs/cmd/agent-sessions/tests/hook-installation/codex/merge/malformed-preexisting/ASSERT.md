## Expected
- `resp.ExitCode == 0` (CLI reports error on stdout, does not exit non-zero).
- `resp.Stdout` contains `"error merging"` or `"parse hooks.json"`.
- `hooks.json` content remains the original malformed `{not json` (not overwritten with valid JSON).

## Side Effects
- Pre-existing malformed file is unchanged.

## Exit Code
- `0`

```go
import (
	"path/filepath"
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 0 {
		t.Fatalf("expected exit code 0 (error reported on stdout), got %d", resp.ExitCode)
	}
	if !strings.Contains(resp.Stdout, "error merging") && !strings.Contains(resp.Stdout, "parse hooks.json") {
		t.Fatalf("stdout missing merge error: %q", resp.Stdout)
	}

	hooksPath := filepath.Join(resp.WorkDir, ".codex", "hooks.json")
	content := resp.Files[hooksPath]
	if content == "MISSING" {
		t.Fatal("expected pre-existing malformed hooks.json to remain")
	}
	if content != "{not json" {
		t.Fatalf("malformed hooks.json was corrupted: got %q", content)
	}

	t.Logf("codex-merge-malformed-preexisting OK")
}
```