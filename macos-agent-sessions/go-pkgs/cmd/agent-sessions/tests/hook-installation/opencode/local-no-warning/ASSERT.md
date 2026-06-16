## Expected
- `resp.ExitCode == 0`.
- `resp.Stdout` does NOT contain `"/config add plugin"`.
- Plugin file exists under `workDir/.opencode/plugins/agent-sessions.ts`.

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
	if strings.Contains(resp.Stdout, "/config add plugin") {
		t.Fatalf("local install must not print /config add plugin hint: %q", resp.Stdout)
	}

	pluginPath := filepath.Join(resp.WorkDir, ".opencode", "plugins", "agent-sessions.ts")
	assertPathIsolated(t, pluginPath, resp.FakeHome, resp.WorkDir)
	if resp.Files[pluginPath] == "MISSING" {
		t.Fatalf("expected plugin at %q", pluginPath)
	}

	t.Logf("opencode-local-no-warning OK")
}
```