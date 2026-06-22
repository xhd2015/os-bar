## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `Examples:`.
- `resp.Stdout` contains a generic agent install example for one of `codex`, `grok`, `pi`, or `opencode` (e.g. `agent-sessions integrations codex --install`).
- `resp.Stdout` still documents `--json` and `--global` flags.

## Side Effects

- No integration files created under `resp.FakeHome` or `resp.WorkDir`.

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

	if !strings.Contains(resp.Stdout, "Examples:") {
		t.Fatalf("integrations --help stdout missing Examples section; got:\n%s", resp.Stdout)
	}
	agentExamples := []string{
		"agent-sessions integrations codex --install",
		"agent-sessions integrations grok --install",
		"agent-sessions integrations pi --install",
		"agent-sessions integrations opencode --install",
	}
	hasAgentExample := false
	for _, ex := range agentExamples {
		if strings.Contains(resp.Stdout, ex) {
			hasAgentExample = true
			break
		}
	}
	if !hasAgentExample {
		t.Fatalf("integrations --help stdout missing generic agent install example; want one of %v; got:\n%s", agentExamples, resp.Stdout)
	}
	for _, want := range []string{"--json", "--global"} {
		if !strings.Contains(resp.Stdout, want) {
			t.Fatalf("integrations --help stdout missing flag %q; got:\n%s", want, resp.Stdout)
		}
	}

	assertNoFilesUnderDir(t, resp.FakeHome)
	assertNoFilesUnderDir(t, resp.WorkDir)

	t.Logf("integrations-help-has-agent-example OK")
}
```