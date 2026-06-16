## Expected
- `resp.ExitCode == 0`.
- `fakeHome/.codex/hooks.json` and `fakeHome/.codex/hooks/agent-sessions-stop.sh` exist.
- No codex files under `workDir`.
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

	hooksPath := filepath.Join(resp.FakeHome, ".codex", "hooks.json")
	scriptPath := filepath.Join(resp.FakeHome, ".codex", "hooks", "agent-sessions-stop.sh")

	for _, p := range []string{hooksPath, scriptPath} {
		assertPathIsolated(t, p, resp.FakeHome, resp.WorkDir)
		if resp.Files[p] == "MISSING" {
			t.Fatalf("expected global codex file %q", p)
		}
		if !strings.HasPrefix(p, resp.FakeHome) {
			t.Fatalf("path %q not under fakeHome", p)
		}
	}

	workHooks := filepath.Join(resp.WorkDir, ".codex", "hooks.json")
	if fileContent(resp, workHooks) != "MISSING" {
		t.Fatalf("unexpected codex hooks.json under workDir")
	}

	t.Logf("codex-empty-hooks-global OK: fakeHome=%s", resp.FakeHome)
}
```