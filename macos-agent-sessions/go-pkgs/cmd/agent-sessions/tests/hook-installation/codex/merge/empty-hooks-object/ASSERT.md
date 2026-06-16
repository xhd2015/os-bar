## Expected
- `resp.ExitCode == 0`.
- `hooks.json` has 1 Stop group with our statusMessage.
- Stop script exists and is executable.

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

	hooksPath := filepath.Join(resp.WorkDir, ".codex", "hooks.json")
	scriptPath := filepath.Join(resp.WorkDir, ".codex", "hooks", "agent-sessions-stop.sh")
	content := resp.Files[hooksPath]
	if content == "MISSING" {
		t.Fatal("expected merged hooks.json")
	}

	if countCodexStopGroups(t, content) != 1 {
		t.Fatalf("expected 1 Stop group added to empty hooks object")
	}
	if countOurStopHandlers(t, content) != 1 {
		t.Fatalf("expected 1 our Stop handler")
	}
	if !strings.Contains(content, agentSessionsHookStatus) {
		t.Fatalf("hooks.json missing our statusMessage")
	}
	if resp.Files[scriptPath] == "MISSING" {
		t.Fatalf("expected stop script at %q", scriptPath)
	}

	t.Logf("codex-merge-empty-hooks-object OK")
}
```