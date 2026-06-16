## Expected
- `resp.ExitCode == 0`.
- Exactly 1 Stop group after merge.
- Exactly 1 handler with our statusMessage.
- Command path updated to `workDir/.codex/hooks/agent-sessions-stop.sh` (not `/old/path.sh`).

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
	content := resp.Files[hooksPath]
	if content == "MISSING" {
		t.Fatal("expected merged hooks.json")
	}

	if countCodexStopGroups(t, content) != 1 {
		t.Fatalf("expected 1 Stop group after upsert")
	}
	if countOurStopHandlers(t, content) != 1 {
		t.Fatalf("expected exactly 1 our Stop handler, no duplicate")
	}
	if strings.Contains(content, "/old/path.sh") {
		t.Fatalf("stale command path not updated")
	}

	var file struct {
		Hooks map[string][]struct {
			Hooks []struct {
				Command       string `json:"command"`
				StatusMessage string `json:"statusMessage"`
			} `json:"hooks"`
		} `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(content), &file); err != nil {
		t.Fatalf("parse hooks: %v", err)
	}
	cmd := file.Hooks["Stop"][0].Hooks[0].Command
	if !samePath(t, cmd, scriptPath) {
		t.Fatalf("command path %q != expected script path %q", cmd, scriptPath)
	}

	t.Logf("codex-merge-upsert-ours OK")
}
```