## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `opencode plugin: install →`.
- OpenCode plugin path under workDir is `MISSING`.

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
	if !strings.Contains(resp.Stdout, "opencode plugin: install →") {
		t.Fatalf("stdout missing opencode plugin install report: %q", resp.Stdout)
	}

	pluginPath := filepath.Join(resp.WorkDir, ".opencode", "plugins", "agent-sessions.ts")
	if fileContent(resp, pluginPath) != "MISSING" {
		t.Fatalf("expected opencode plugin to be MISSING in dry-run")
	}

	t.Logf("opencode-dry-run-missing OK")
}
```