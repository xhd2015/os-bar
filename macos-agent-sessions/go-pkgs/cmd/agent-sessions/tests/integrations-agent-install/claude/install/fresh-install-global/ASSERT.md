## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` shows shortened global paths (`~/.claude/hooks/...`, `~/.claude/settings.json`) on install arrow lines.
- `resp.Stdout` does not contain the global install hint.
- `resp.Stdout` does not leak absolute `resp.FakeHome` or `resp.WorkDir` paths.
- `fakeHome/.claude/settings.json` and `fakeHome/.claude/hooks/agent-sessions-stop.sh` exist.
- No claude files under `workDir`.

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

	assertClaudeInstallStdoutShortened(t, resp.Stdout, resp, true)
	assertNoClaudeGlobalHint(t, resp.Stdout)

	settingsPath := filepath.Join(resp.FakeHome, ".claude", "settings.json")
	scriptPath := filepath.Join(resp.FakeHome, ".claude", "hooks", "agent-sessions-stop.sh")

	for _, p := range []string{settingsPath, scriptPath} {
		assertPathIsolated(t, p, resp.FakeHome, resp.WorkDir)
		if fileContent(resp, p) == "MISSING" {
			t.Fatalf("expected global claude file %q", p)
		}
		if !strings.HasPrefix(p, resp.FakeHome) {
			t.Fatalf("path %q not under fakeHome", p)
		}
	}

	workSettings := filepath.Join(resp.WorkDir, ".claude", "settings.json")
	if fileContent(resp, workSettings) != "MISSING" {
		t.Fatalf("unexpected claude settings.json under workDir")
	}

	t.Logf("claude-fresh-install-global OK")
}
```
