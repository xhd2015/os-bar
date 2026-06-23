## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` shows shortened local paths (`.codex/hooks/...`, `.codex/hooks.json`) on install arrow lines.
- `resp.Stdout` contains the global install hint with `agent-sessions integrations codex --install --global`.
- `resp.Stdout` does not leak absolute `resp.FakeHome` or `resp.WorkDir` paths.
- `workDir/.codex/hooks.json` exists and contains exactly one Stop group with our statusMessage.
- `workDir/.codex/hooks/agent-sessions-stop.sh` exists and is executable.
- Command path in hooks.json points to the absolute installed script path under workDir (not shortened).

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
		t.Fatalf("expected exit code 0, got %d; stderr=%q", resp.ExitCode, resp.Stderr)
	}

	assertCodexInstallStdoutShortened(t, resp.Stdout, resp, false)
	assertCodexGlobalHint(t, resp.Stdout)

	hooksPath := filepath.Join(resp.WorkDir, ".codex", "hooks.json")
	scriptPath := filepath.Join(resp.WorkDir, ".codex", "hooks", "agent-sessions-stop.sh")

	assertPathIsolated(t, hooksPath, resp.FakeHome, resp.WorkDir)
	if fileContent(resp, hooksPath) == "MISSING" {
		t.Fatalf("expected hooks.json at %q", hooksPath)
	}
	if fileContent(resp, scriptPath) == "MISSING" {
		t.Fatalf("expected stop script at %q", scriptPath)
	}
	if !resp.ScriptExecutable[scriptPath] {
		t.Fatalf("stop script not executable: %q", scriptPath)
	}

	hooksJSON := fileContent(resp, hooksPath)
	if countCodexStopGroups(t, hooksJSON) != 1 {
		t.Fatalf("expected 1 Stop group in fresh hooks.json")
	}
	if countOurStopHandlers(t, hooksJSON) != 1 {
		t.Fatalf("expected exactly 1 our Stop handler")
	}
	if !strings.Contains(hooksJSON, agentSessionsHookStatus) {
		t.Fatalf("hooks.json missing our statusMessage")
	}

	var file struct {
		Hooks map[string][]struct {
			Hooks []struct {
				Command string `json:"command"`
			} `json:"hooks"`
		} `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(hooksJSON), &file); err != nil {
		t.Fatalf("parse hooks: %v", err)
	}
	cmd := file.Hooks["Stop"][0].Hooks[0].Command
	if !samePath(t, cmd, scriptPath) {
		t.Fatalf("command path %q != absolute script path %q", cmd, scriptPath)
	}
	if strings.HasPrefix(cmd, ".codex/") || strings.HasPrefix(cmd, "~/") {
		t.Fatalf("hooks.json command must stay absolute, got %q", cmd)
	}

	t.Logf("codex-fresh-install-local OK")
}
```