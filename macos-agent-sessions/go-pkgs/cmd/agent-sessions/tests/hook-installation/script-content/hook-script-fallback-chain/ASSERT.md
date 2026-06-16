## Expected
- `resp.ExitCode == 0`.
- Stop script at `workDir/.grok/hooks/bin/agent-sessions-stop.sh` contains:
  - `jq`
  - `python3`
  - `node`
  - `grep -oE` (grep fallback marker)

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

	scriptPath := filepath.Join(resp.WorkDir, ".grok", "hooks", "bin", "agent-sessions-stop.sh")
	script := resp.Files[scriptPath]
	if script == "MISSING" {
		t.Fatalf("expected stop script at %q", scriptPath)
	}

	for _, marker := range []string{"jq", "python3", "node", "grep -oE"} {
		if !strings.Contains(script, marker) {
			t.Fatalf("hook script missing fallback marker %q", marker)
		}
	}

	t.Logf("hook-script-fallback-chain OK")
}
```