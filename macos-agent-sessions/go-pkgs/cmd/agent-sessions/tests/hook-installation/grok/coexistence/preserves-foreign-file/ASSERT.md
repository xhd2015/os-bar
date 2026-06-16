## Expected
- `resp.ExitCode == 0`.
- Foreign file `workDir/.grok/hooks/other-hooks.json` exists and matches the pre-seed fixture exactly.
- Our `agent-sessions.json` exists with a `Stop` hook.
- Our `bin/agent-sessions-stop.sh` exists and is executable.

## Side Effects
- Foreign hook file is not modified or deleted.

## Errors
- If foreign file content differs from fixture, test fails.
- If our files are missing, test fails.

```go
import (
	"os"
	"path/filepath"
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 0 {
		t.Fatalf("expected exit 0, got %d stderr=%q", resp.ExitCode, resp.Stderr)
	}

	foreignPath := filepath.Join(resp.WorkDir, ".grok", "hooks", "other-hooks.json")
	assertPathIsolated(t, foreignPath, resp.FakeHome, resp.WorkDir)

	foreignContent, readErr := os.ReadFile(foreignPath)
	if readErr != nil {
		t.Fatalf("foreign hook file missing: %v", readErr)
	}
	fixturePath := filepath.Join(DOCTEST_ROOT, "testdata", "grok-foreign-hooks.json")
	fixtureBytes, err := os.ReadFile(fixturePath)
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	if strings.TrimSpace(string(foreignContent)) != strings.TrimSpace(string(fixtureBytes)) {
		t.Fatalf("foreign hook file was modified:\ngot:\n%s\nwant:\n%s", foreignContent, fixtureBytes)
	}

	jsonPath := filepath.Join(resp.WorkDir, ".grok", "hooks", "agent-sessions.json")
	scriptPath := filepath.Join(resp.WorkDir, ".grok", "hooks", "bin", "agent-sessions-stop.sh")
	if fileContent(resp, jsonPath) == "MISSING" {
		t.Fatalf("expected our agent-sessions.json at %s", jsonPath)
	}
	if !grokHooksHasStop(t, resp.Files[jsonPath]) {
		t.Fatalf("agent-sessions.json missing Stop hook")
	}
	if fileContent(resp, scriptPath) == "MISSING" {
		t.Fatalf("expected stop script at %s", scriptPath)
	}
	if !resp.ScriptExecutable[scriptPath] {
		t.Fatalf("stop script not executable: %s", scriptPath)
	}

	t.Logf("grok-coexistence-preserves-foreign-file OK: foreign=%s", foreignPath)
}
```