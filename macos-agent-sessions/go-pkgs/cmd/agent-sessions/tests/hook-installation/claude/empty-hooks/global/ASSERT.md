## Expected
- `resp.ExitCode == 0`.
- `fakeHome/.claude/settings.json` and `fakeHome/.claude/hooks/agent-sessions-stop.sh` exist.
- No claude files under `workDir`.
- Paths are under `fakeHome` only (isolation).

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

	settingsPath := filepath.Join(resp.FakeHome, ".claude", "settings.json")
	scriptPath := filepath.Join(resp.FakeHome, ".claude", "hooks", "agent-sessions-stop.sh")

	for _, p := range []string{settingsPath, scriptPath} {
		assertPathIsolated(t, p, resp.FakeHome, resp.WorkDir)
		if resp.Files[p] == "MISSING" {
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

	t.Logf("claude-empty-hooks-global OK: fakeHome=%s", resp.FakeHome)
}
```
