## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` equals `resp.HelpReferenceStdout` (bare invocation matches `--help`).
- Help text describes purpose and lists flags (`--install`, `--dry-run`, `-h`, `--help`).
- Help text describes direct sourcing via `~/.bash_profile`.
- Help text does not reference `.local/share/bash-completion`.
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
		t.Fatalf("bare bash-completions stdout differs from --help\nbare:\n%s\n--help:\n%s", resp.Stdout, resp.HelpReferenceStdout)
	}

	for _, flag := range []string{"--install", "--dry-run", "--help", ".bash_profile", ".config/agent-sessions"} {
		if !strings.Contains(resp.Stdout, flag) {
			t.Fatalf("bash-completions help missing %q", flag)
		}
	}
	if strings.Contains(resp.Stdout, ".local/share/bash-completion") {
		t.Fatalf("help must not reference bash-completion framework directory")
	}
	if !strings.Contains(resp.Stdout, "Examples:") {
		t.Fatalf("bash-completions help missing Examples section")
	}

	t.Logf("bash-completions-help-default OK")
}
```