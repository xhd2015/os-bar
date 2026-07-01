## Expected
- `resp.ExitCode == 0` (CLI reports error on stdout, does not exit non-zero).
- `resp.Stdout` contains `"error merging"` or `"parse settings.json"` (or a parse error).
- `settings.json` content remains the original malformed `{not json` (not overwritten with valid JSON).

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
	if !strings.Contains(resp.Stdout, "error merging") && !strings.Contains(resp.Stdout, "parse settings.json") && !strings.Contains(resp.Stdout, "parse") {
		t.Fatalf("stdout missing merge error: %q", resp.Stdout)
	}

	settingsPath := filepath.Join(resp.WorkDir, ".claude", "settings.json")
	content := resp.Files[settingsPath]
	if content == "MISSING" {
		t.Fatal("expected pre-existing malformed settings.json to remain")
	}
	if content != "{not json" {
		t.Fatalf("malformed settings.json was corrupted: got %q", content)
	}

	t.Logf("claude-merge-malformed-preexisting OK")
}
```
