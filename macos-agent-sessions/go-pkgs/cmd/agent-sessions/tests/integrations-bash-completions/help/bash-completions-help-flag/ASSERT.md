## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains usage for `bash-completions`.
- `resp.Stdout` documents `--install` and `--dry-run`.
- `resp.Stdout` describes direct sourcing via `~/.bash_profile` and completion path under `.config/agent-sessions`.
- `resp.Stdout` does not reference bash-completion framework directory `.local/share/bash-completion`.
- `resp.Stdout` contains `Examples:`.

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

	for _, want := range []string{"bash-completions", "--install", "--dry-run", "Examples:", ".bash_profile", ".config/agent-sessions"} {
		if !strings.Contains(resp.Stdout, want) {
			t.Fatalf("bash-completions --help stdout missing %q; got:\n%s", want, resp.Stdout)
		}
	}
	if strings.Contains(resp.Stdout, ".local/share/bash-completion") {
		t.Fatalf("help must not reference bash-completion framework directory; got:\n%s", resp.Stdout)
	}

	t.Logf("bash-completions-help-flag OK")
}
```