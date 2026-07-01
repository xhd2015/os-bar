## Expected
- `resp.ExitCode == 0`.
- Exactly 1 Stop group after merge.
- Exactly 1 handler with our statusMessage.
- Command updated to contain `AGENT_SESSIONS_AGENT=claude` and the new script path (not `/old/path.sh`).

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

	settingsPath := filepath.Join(resp.WorkDir, ".claude", "settings.json")
	scriptPath := filepath.Join(resp.WorkDir, ".claude", "hooks", "agent-sessions-stop.sh")
	content := resp.Files[settingsPath]
	if content == "MISSING" {
		t.Fatal("expected merged settings.json")
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

	if !strings.Contains(content, "AGENT_SESSIONS_AGENT=claude") {
		t.Fatalf("merged settings missing AGENT_SESSIONS_AGENT=claude prefix")
	}
	if !strings.Contains(content, scriptPath) {
		t.Fatalf("merged settings missing new script path %q", scriptPath)
	}

	t.Logf("claude-merge-upsert-ours OK")
}
```
