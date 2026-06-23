## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `Usage:` and `integrations codex`.
- Help text lists `--install`, `--dry-run`, and `--global`.
- Help text contains `Examples:`.
- Help text does not contain the codex global install hint.

## Exit Code

- `0`

```go
import (
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 0 {
		t.Fatalf("expected exit code 0, got %d; stderr=%q", resp.ExitCode, resp.Stderr)
	}

	for _, want := range []string{"Usage:", "integrations codex", "--install", "--dry-run", "--global", "Examples:"} {
		if !strings.Contains(resp.Stdout, want) {
			t.Fatalf("codex --help stdout missing %q; got:\n%s", want, resp.Stdout)
		}
	}
	assertNoCodexGlobalHint(t, resp.Stdout)

	t.Logf("codex-help-flag OK")
}
```