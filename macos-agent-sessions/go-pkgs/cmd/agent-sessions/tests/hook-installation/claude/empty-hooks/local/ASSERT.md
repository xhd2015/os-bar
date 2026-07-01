## Expected
- `resp.ExitCode == 0`.
- `workDir/.claude/settings.json` exists and contains exactly one Stop group with our statusMessage.
- `workDir/.claude/hooks/agent-sessions-stop.sh` exists and is executable (mode `& 0111 != 0`).
- The our-handler command contains `AGENT_SESSIONS_AGENT=claude` and the absolute script path.
- The our-handler has no `env` key.

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

	settingsPath := filepath.Join(resp.WorkDir, ".claude", "settings.json")
	scriptPath := filepath.Join(resp.WorkDir, ".claude", "hooks", "agent-sessions-stop.sh")

	assertPathIsolated(t, settingsPath, resp.FakeHome, resp.WorkDir)
	if resp.Files[settingsPath] == "MISSING" {
		t.Fatalf("expected settings.json at %q", settingsPath)
	}
	if resp.Files[scriptPath] == "MISSING" {
		t.Fatalf("expected stop script at %q", scriptPath)
	}
	if !resp.ScriptExecutable[scriptPath] {
		t.Fatalf("stop script not executable: %q", scriptPath)
	}

	if countCodexStopGroups(t, resp.Files[settingsPath]) != 1 {
		t.Fatalf("expected 1 Stop group in fresh settings.json")
	}
	if countOurStopHandlers(t, resp.Files[settingsPath]) != 1 {
		t.Fatalf("expected exactly 1 our Stop handler")
	}
	if !strings.Contains(resp.Files[settingsPath], agentSessionsHookStatus) {
		t.Fatalf("settings.json missing our statusMessage")
	}

	var file struct {
		Hooks map[string][]struct {
			Hooks []struct {
				Command       string            `json:"command"`
				StatusMessage string            `json:"statusMessage"`
				Env           map[string]string `json:"env"`
			} `json:"hooks"`
		} `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(resp.Files[settingsPath]), &file); err != nil {
		t.Fatalf("parse settings: %v", err)
	}
	handler := file.Hooks["Stop"][0].Hooks[0]
	if handler.StatusMessage != agentSessionsHookStatus {
		t.Fatalf("first Stop handler is not ours: %q", handler.StatusMessage)
	}
	cmd := handler.Command
	if !strings.Contains(cmd, "AGENT_SESSIONS_AGENT=claude") {
		t.Fatalf("command missing AGENT_SESSIONS_AGENT=claude prefix: %q", cmd)
	}
	if !strings.Contains(cmd, scriptPath) {
		t.Fatalf("command %q does not contain script path %q", cmd, scriptPath)
	}
	if handler.Env != nil {
		t.Fatalf("claude our-handler must NOT carry an env field, got %v", handler.Env)
	}

	t.Logf("claude-empty-hooks-local OK")
}
```
