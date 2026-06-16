## Expected
- `resp.ExitCode == 0`.
- `workDir/.pi/extensions/agent-sessions-hook.ts` exists with non-empty content.
- Path is under `workDir` (isolation).

## Exit Code
- `0`

```go
import "path/filepath"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 0 {
		t.Fatalf("expected exit code 0, got %d", resp.ExitCode)
	}

	extPath := filepath.Join(resp.WorkDir, ".pi", "extensions", "agent-sessions-hook.ts")
	assertPathIsolated(t, extPath, resp.FakeHome, resp.WorkDir)
	content := resp.Files[extPath]
	if content == "MISSING" {
		t.Fatalf("expected pi extension at %q", extPath)
	}
	if len(content) == 0 {
		t.Fatal("pi extension file is empty")
	}

	t.Logf("pi-local-install OK: %s (%d bytes)", extPath, len(content))
}
```