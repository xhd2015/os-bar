## Expected
- `resp.ExitCode == 0`.
- `workDir/.codex/hooks.json` exists and contains exactly one Stop group with our statusMessage.
- `workDir/.codex/hooks/agent-sessions-stop.sh` exists and is executable.
- Command path in hooks.json points to the installed script path under workDir.

## Exit Code
- `0`

```go
import (
	"encoding/json"
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

	hooksPath := filepath.Join(resp.WorkDir, ".codex", "hooks.json")
	scriptPath := filepath.Join(resp.WorkDir, ".codex", "hooks", "agent-sessions-stop.sh")

	assertPathIsolated(t, hooksPath, resp.FakeHome, resp.WorkDir)
	if resp.Files[hooksPath] == "MISSING" {
		t.Fatalf("expected hooks.json at %q", hooksPath)
	}
	if resp.Files[scriptPath] == "MISSING" {
		t.Fatalf("expected stop script at %q", scriptPath)
	}
	if !resp.ScriptExecutable[scriptPath] {
		t.Fatalf("stop script not executable: %q", scriptPath)
	}

	if countCodexStopGroups(t, resp.Files[hooksPath]) != 1 {
		t.Fatalf("expected 1 Stop group in fresh hooks.json")
	}
	if countOurStopHandlers(t, resp.Files[hooksPath]) != 1 {
		t.Fatalf("expected exactly 1 our Stop handler")
	}
	if !strings.Contains(resp.Files[hooksPath], agentSessionsHookStatus) {
		t.Fatalf("hooks.json missing our statusMessage")
	}
	var file struct {
		Hooks map[string][]struct {
			Hooks []struct {
				Command string `json:"command"`
			} `json:"hooks"`
		} `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(resp.Files[hooksPath]), &file); err != nil {
		t.Fatalf("parse hooks: %v", err)
	}
	cmd := file.Hooks["Stop"][0].Hooks[0].Command
	if !samePath(t, cmd, scriptPath) {
		t.Fatalf("command path %q != script path %q", cmd, scriptPath)
	}

	t.Logf("codex-empty-hooks-local OK")
}
```