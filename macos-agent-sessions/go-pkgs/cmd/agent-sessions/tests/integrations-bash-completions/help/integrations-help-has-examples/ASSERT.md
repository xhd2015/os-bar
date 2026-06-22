## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `Examples:`.
- `resp.Stdout` contains example lines for default listing, scope filters, JSON, and bash-completions install.
- `resp.Stdout` documents `--local`, dual-scope default, and `--json` as machine-readable JSON.

## Side Effects

- No completion file created under `resp.FakeHome`.

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

	requiredSubstrings := []string{
		"Examples:",
		"agent-sessions integrations",
		"agent-sessions integrations --global",
		"agent-sessions integrations --local",
		"agent-sessions integrations --json",
		"agent-sessions integrations bash-completions --install",
	}
	for _, want := range requiredSubstrings {
		if !strings.Contains(resp.Stdout, want) {
			t.Fatalf("integrations --help stdout missing %q; got:\n%s", want, resp.Stdout)
		}
	}

	flagHints := []string{
		"--json",
		"--local",
		"--global",
		"global",
		"local",
	}
	for _, want := range flagHints {
		if !strings.Contains(resp.Stdout, want) {
			t.Fatalf("integrations --help stdout missing flag hint %q; got:\n%s", want, resp.Stdout)
		}
	}

	if completionContent(resp.CompletionPath, resp) != "MISSING" {
		t.Fatalf("expected no completion file during help-only invocation")
	}

	t.Logf("integrations-help-has-examples OK")
}
```