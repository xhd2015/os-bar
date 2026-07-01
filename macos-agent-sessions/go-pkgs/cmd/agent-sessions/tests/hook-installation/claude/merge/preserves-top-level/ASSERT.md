## Expected
- `resp.ExitCode == 0`.
- Top-level keys `permissions`, `env`, `model` still present in settings.json.
- `UserPromptSubmit` foreign hook (1 group) preserved.
- `Stop` has 2 groups (foreign `skynet stop` + ours).
- Foreign `skynet stop` handler preserved; our `os-bar agent-sessions notify` handler present.
- Our handler command contains `AGENT_SESSIONS_AGENT=claude`.

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
	content := resp.Files[settingsPath]
	if content == "MISSING" {
		t.Fatal("expected merged settings.json")
	}

	// All top-level keys preserved.
	var root map[string]json.RawMessage
	if err := json.Unmarshal([]byte(content), &root); err != nil {
		t.Fatalf("parse settings: %v", err)
	}
	for _, key := range []string{"permissions", "env", "model", "hooks"} {
		if _, ok := root[key]; !ok {
			t.Fatalf("merge removed top-level key %q", key)
		}
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
	ourCommand := ""
	for _, groupRaw := range hooks["Stop"] {
		var group struct {
			Hooks []struct {
				StatusMessage string `json:"statusMessage"`
				Command       string `json:"command"`
			} `json:"hooks"`
		}
		if err := json.Unmarshal(groupRaw, &group); err != nil {
			t.Fatalf("parse Stop group: %v", err)
		}
		for _, h := range group.Hooks {
			switch h.StatusMessage {
			case agentSessionsHookStatus:
				foundOurs = true
				ourCommand = h.Command
			case "skynet stop":
				foundOther = true
			}
		}
	}
	if !foundOurs || !foundOther {
		t.Fatalf("missing hooks: ours=%v other=%v", foundOurs, foundOther)
	}
	if !strings.Contains(ourCommand, "AGENT_SESSIONS_AGENT=claude") {
		t.Fatalf("our handler command missing AGENT_SESSIONS_AGENT=claude: %q", ourCommand)
	}
	if !strings.Contains(content, "/bin/skynet.sh") {
		t.Fatalf("foreign Stop command removed")
	}

	t.Logf("claude-merge-preserves-top-level OK")
}
```
