## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` shows shortened local paths (`.claude/hooks/...`, `.claude/settings.json`) on install arrow lines.
- `resp.Stdout` contains the global install hint with `agent-sessions integrations claude --install --global`.
- `resp.Stdout` does not leak absolute `resp.FakeHome` or `resp.WorkDir` paths.
- `workDir/.claude/settings.json` exists and contains exactly one Stop group with our statusMessage.
- `workDir/.claude/hooks/agent-sessions-stop.sh` exists and is executable.
- The our-handler command in settings.json contains `AGENT_SESSIONS_AGENT=claude` and the absolute installed script path under workDir (not shortened).

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

	assertClaudeInstallStdoutShortened(t, resp.Stdout, resp, false)
	assertClaudeGlobalHint(t, resp.Stdout)

	settingsPath := filepath.Join(resp.WorkDir, ".claude", "settings.json")
	scriptPath := filepath.Join(resp.WorkDir, ".claude", "hooks", "agent-sessions-stop.sh")

	assertPathIsolated(t, settingsPath, resp.FakeHome, resp.WorkDir)
	if fileContent(resp, settingsPath) == "MISSING" {
		t.Fatalf("expected settings.json at %q", settingsPath)
	}
	if fileContent(resp, scriptPath) == "MISSING" {
		t.Fatalf("expected stop script at %q", scriptPath)
	}
	if !resp.ScriptExecutable[scriptPath] {
		t.Fatalf("stop script not executable: %q", scriptPath)
	}

	settingsJSON := fileContent(resp, settingsPath)
	if countCodexStopGroups(t, settingsJSON) != 1 {
		t.Fatalf("expected 1 Stop group in fresh settings.json")
	}
	if countOurStopHandlers(t, settingsJSON) != 1 {
		t.Fatalf("expected exactly 1 our Stop handler")
	}
	if !strings.Contains(settingsJSON, agentSessionsHookStatus) {
		t.Fatalf("settings.json missing our statusMessage")
	}
	if !strings.Contains(settingsJSON, "AGENT_SESSIONS_AGENT=claude") {
		t.Fatalf("settings.json command missing AGENT_SESSIONS_AGENT=claude prefix")
	}
	if !strings.Contains(settingsJSON, scriptPath) {
		t.Fatalf("settings.json command missing absolute script path %q", scriptPath)
	}
	// The command string stays absolute: the part after the AGENT_SESSIONS_AGENT=claude
	// prefix (which may be single-quote-wrapped) must be the absolute script path, never
	// a shortened (.claude/... or ~/...) form.
	tail := strings.TrimPrefix(settingsJSON, "AGENT_SESSIONS_AGENT=claude")
	// Find the scriptPath occurrence within tail to confirm it is the absolute path,
	// not a shortened relative variant.
	if !strings.Contains(tail, scriptPath) {
		t.Fatalf("settings.json command must reference the absolute script path %q", scriptPath)
	}

	t.Logf("claude-fresh-install-local OK")
}
```
