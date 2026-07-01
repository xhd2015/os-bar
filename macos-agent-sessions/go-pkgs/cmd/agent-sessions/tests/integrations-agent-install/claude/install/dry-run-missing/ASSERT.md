## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `claude settings: install →` with shortened local `.claude/settings.json` path.
- `resp.Stdout` contains shortened `.claude/hooks/agent-sessions-stop.sh` path for the hook script line.
- `resp.Stdout` does not contain the global install hint.
- `resp.Stdout` does not leak absolute temp directory prefixes.
- `workDir/.claude/settings.json` is `MISSING`.

## Side Effects

- No claude files created under `resp.WorkDir` or `resp.FakeHome`.

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
	if !strings.Contains(resp.Stdout, "claude settings: install →") {
		t.Fatalf("stdout missing claude install report: %q", resp.Stdout)
	}

	assertClaudeInstallStdoutShortened(t, resp.Stdout, resp, false)
	assertNoClaudeGlobalHint(t, resp.Stdout)

	settingsPath := filepath.Join(resp.WorkDir, ".claude", "settings.json")
	if fileContent(resp, settingsPath) != "MISSING" {
		t.Fatalf("expected settings.json to be MISSING in dry-run, got content")
	}

	t.Logf("claude-dry-run-missing OK")
}
```
