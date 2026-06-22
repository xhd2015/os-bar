## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `pi extension: install →`.
- Pi extension path under workDir is `MISSING`.

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
	if !strings.Contains(resp.Stdout, "pi extension: install →") {
		t.Fatalf("stdout missing pi extension install report: %q", resp.Stdout)
	}

	extPath := filepath.Join(resp.WorkDir, ".pi", "extensions", "agent-sessions-hook.ts")
	if fileContent(resp, extPath) != "MISSING" {
		t.Fatalf("expected pi extension to be MISSING in dry-run")
	}

	t.Logf("pi-dry-run-missing OK")
}
```