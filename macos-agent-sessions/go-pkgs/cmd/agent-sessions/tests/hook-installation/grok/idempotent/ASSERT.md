## Expected
- `resp.ExitCode == 0`.
- `resp.StdoutSecond` contains `"up to date"`.
- File snapshot after second run: exactly 2 grok artifacts exist (JSON + script), unchanged.

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
	if !strings.Contains(resp.StdoutSecond, "up to date") {
		t.Fatalf("second run stdout missing 'up to date': %q", resp.StdoutSecond)
	}

	existing := 0
	for path, content := range resp.Files {
		if content != "MISSING" {
			existing++
			assertPathIsolated(t, path, resp.FakeHome, resp.WorkDir)
		}
	}
	if existing != 2 {
		t.Fatalf("expected 2 grok files after idempotent install, got %d", existing)
	}

	jsonPath := filepath.Join(resp.WorkDir, ".grok", "hooks", "agent-sessions.json")
	if resp.Files[jsonPath] == "MISSING" {
		t.Fatalf("expected grok hooks JSON to exist after idempotent install")
	}

	t.Logf("grok-idempotent OK: second_stdout=%q", resp.StdoutSecond)
}
```