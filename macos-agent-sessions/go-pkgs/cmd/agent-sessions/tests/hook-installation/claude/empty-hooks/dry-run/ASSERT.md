## Expected
- `resp.ExitCode == 0`.
- `resp.Stdout` contains `"install →"` for claude settings.
- `workDir/.claude/settings.json` is `MISSING`.

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
		t.Fatalf("expected exit code 0, got %d", resp.ExitCode)
	}
	if !strings.Contains(resp.Stdout, "claude settings: install →") {
		t.Fatalf("stdout missing claude install report: %q", resp.Stdout)
	}

	settingsPath := filepath.Join(resp.WorkDir, ".claude", "settings.json")
	if resp.Files[settingsPath] != "MISSING" {
		t.Fatalf("expected settings.json to be MISSING in dry-run, got content")
	}

	t.Logf("claude-dry-run-empty OK")
}
```
