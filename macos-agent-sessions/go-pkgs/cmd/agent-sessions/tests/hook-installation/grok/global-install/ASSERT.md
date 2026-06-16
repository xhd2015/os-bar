## Expected
- `resp.ExitCode == 0`.
- Hook JSON and stop script exist under `resp.FakeHome/.grok/hooks/`.
- Corresponding paths under `resp.WorkDir` are `MISSING`.
- All written paths are under `resp.FakeHome` (isolation).

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

	jsonPath := filepath.Join(resp.FakeHome, ".grok", "hooks", "agent-sessions.json")
	scriptPath := filepath.Join(resp.FakeHome, ".grok", "hooks", "bin", "agent-sessions-stop.sh")

	for _, p := range []string{jsonPath, scriptPath} {
		assertPathIsolated(t, p, resp.FakeHome, resp.WorkDir)
		if resp.Files[p] == "MISSING" {
			t.Fatalf("expected global file %q to exist", p)
		}
		if !strings.HasPrefix(p, resp.FakeHome) {
			t.Fatalf("global path %q not under fakeHome %q", p, resp.FakeHome)
		}
	}

	workJSON := filepath.Join(resp.WorkDir, ".grok", "hooks", "agent-sessions.json")
	workScript := filepath.Join(resp.WorkDir, ".grok", "hooks", "bin", "agent-sessions-stop.sh")
	if fileContent(resp, workJSON) != "MISSING" || fileContent(resp, workScript) != "MISSING" {
		t.Fatalf("expected no grok files under workDir")
	}

	t.Logf("grok-global-install OK: fakeHome=%s", resp.FakeHome)
}
```