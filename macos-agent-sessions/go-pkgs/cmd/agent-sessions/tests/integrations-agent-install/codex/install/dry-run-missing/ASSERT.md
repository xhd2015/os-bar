## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `codex hooks: install →`.
- `workDir/.codex/hooks.json` is `MISSING`.

## Side Effects

- No codex files created under `resp.WorkDir` or `resp.FakeHome`.

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
		t.Fatalf("expected exit code 0, got %d; stderr=%q", resp.ExitCode, resp.Stderr)
	}
	if !strings.Contains(resp.Stdout, "codex hooks: install →") {
		t.Fatalf("stdout missing codex install report: %q", resp.Stdout)
	}

	hooksPath := filepath.Join(resp.WorkDir, ".codex", "hooks.json")
	if fileContent(resp, hooksPath) != "MISSING" {
		t.Fatalf("expected hooks.json to be MISSING in dry-run, got content")
	}

	t.Logf("codex-dry-run-missing OK")
}
```