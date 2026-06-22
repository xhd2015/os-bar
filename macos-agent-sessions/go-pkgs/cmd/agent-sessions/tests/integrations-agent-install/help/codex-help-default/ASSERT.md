## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` equals `resp.HelpReferenceStdout` (bare invocation matches `--help`).
- Help text describes purpose and lists flags (`--install`, `--dry-run`, `--global`, `-h`, `--help`).
- Help text contains an `Examples:` section.

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
	if resp.Stdout != resp.HelpReferenceStdout {
		t.Fatalf("bare codex stdout differs from --help\nbare:\n%s\n--help:\n%s", resp.Stdout, resp.HelpReferenceStdout)
	}

	for _, flag := range []string{"--install", "--dry-run", "--global", "--help"} {
		if !strings.Contains(resp.Stdout, flag) {
			t.Fatalf("codex help missing %q; got:\n%s", flag, resp.Stdout)
		}
	}
	if !strings.Contains(resp.Stdout, "Examples:") {
		t.Fatalf("codex help missing Examples section; got:\n%s", resp.Stdout)
	}

	t.Logf("codex-help-default OK")
}
```