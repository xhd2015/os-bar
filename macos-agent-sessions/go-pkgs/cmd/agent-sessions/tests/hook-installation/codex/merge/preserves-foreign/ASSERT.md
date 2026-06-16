## Expected
- `resp.ExitCode == 0`.
- `hooks.json` has `UserPromptSubmit` (1 group) and `Stop` (2 groups).
- Foreign `skynet stop` handler preserved.
- Our `os-bar agent-sessions notify` handler present.

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
	content := resp.Files[hooksPath]
	if content == "MISSING" {
		t.Fatal("expected merged hooks.json")
	}

	hooks := parseCodexHooks(t, content)
	if len(hooks["UserPromptSubmit"]) != 1 {
		t.Fatalf("UserPromptSubmit group removed — merge must preserve foreign hooks")
	}
	if len(hooks["Stop"]) != 2 {
		t.Fatalf("expected 2 Stop groups, got %d", len(hooks["Stop"]))
	}

	foundOurs := false
	foundOther := false
	for _, groupRaw := range hooks["Stop"] {
		var group struct {
			Hooks []struct {
				StatusMessage string `json:"statusMessage"`
			} `json:"hooks"`
		}
		if err := json.Unmarshal(groupRaw, &group); err != nil {
			t.Fatalf("parse Stop group: %v", err)
		}
		for _, h := range group.Hooks {
			switch h.StatusMessage {
			case agentSessionsHookStatus:
				foundOurs = true
			case "skynet stop":
				foundOther = true
			}
		}
	}
	if !foundOurs || !foundOther {
		t.Fatalf("missing hooks: ours=%v other=%v", foundOurs, foundOther)
	}
	if !strings.Contains(content, "/bin/other.sh") {
		t.Fatalf("foreign UserPromptSubmit command removed")
	}

	t.Logf("codex-merge-preserves-foreign OK")
}
```