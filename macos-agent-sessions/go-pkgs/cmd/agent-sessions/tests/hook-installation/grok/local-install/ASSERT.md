## Expected
- `resp.ExitCode == 0`.
- Two files exist under `resp.WorkDir`:
  - `.grok/hooks/agent-sessions.json` — contains a `Stop` hook.
  - `.grok/hooks/bin/agent-sessions-stop.sh` — executable (`0755`).
- All snapshot paths are under `resp.WorkDir` (isolation).
- No hook files under `resp.FakeHome`.

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
		t.Fatalf("expected exit code 0, got %d; stderr=%s", resp.ExitCode, resp.Stderr)
	}

	jsonPath := filepath.Join(resp.WorkDir, ".grok", "hooks", "agent-sessions.json")
	scriptPath := filepath.Join(resp.WorkDir, ".grok", "hooks", "bin", "agent-sessions-stop.sh")

	for _, p := range []string{jsonPath, scriptPath} {
		assertPathIsolated(t, p, resp.FakeHome, resp.WorkDir)
		if resp.Files[p] == "MISSING" {
			t.Fatalf("expected file %q to exist", p)
		}
	}

	if !grokHooksHasStop(t, resp.Files[jsonPath]) {
		t.Fatalf("grok hooks JSON missing Stop hook")
	}
	if !resp.ScriptExecutable[scriptPath] {
		t.Fatalf("stop script %q is not executable", scriptPath)
	}

	for path, content := range resp.Files {
		if content != "MISSING" && strings.HasPrefix(path, resp.FakeHome) {
			t.Fatalf("unexpected file under fakeHome: %s", path)
		}
	}

	t.Logf("grok-local-install OK: json=%s script=%s", jsonPath, scriptPath)
}
```