## Expected
- `resp.ExitCode == 0`.
- Plugin exists at `fakeHome/.config/opencode/plugins/agent-sessions.ts`.
- Path is under `fakeHome` (isolation).
- No plugin under `workDir`.

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

	pluginPath := filepath.Join(resp.FakeHome, ".config", "opencode", "plugins", "agent-sessions.ts")
	assertPathIsolated(t, pluginPath, resp.FakeHome, resp.WorkDir)
	if resp.Files[pluginPath] == "MISSING" {
		t.Fatalf("expected global plugin at %q", pluginPath)
	}
	if !strings.HasPrefix(pluginPath, resp.FakeHome) {
		t.Fatalf("plugin path not under fakeHome")
	}

	workPlugin := filepath.Join(resp.WorkDir, ".opencode", "plugins", "agent-sessions.ts")
	if fileContent(resp, workPlugin) != "MISSING" {
		t.Fatalf("unexpected local plugin under workDir")
	}

	t.Logf("opencode-global-install OK")
}
```