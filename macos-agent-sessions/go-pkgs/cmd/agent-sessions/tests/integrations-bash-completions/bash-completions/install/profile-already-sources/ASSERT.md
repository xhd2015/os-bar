## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `installed bash completion:` and `resp.CompletionPath`.
- `resp.Stdout` does not contain `updated bash profile:`.
- Completion file exists with bundled markers.
- Bash profile content is byte-identical to pre-seeded profile.

## Side Effects

- Creates `$HOME/.config/agent-sessions/bash-completion.bash`.
- Does not modify `$HOME/.bash_profile`.

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
	if !strings.Contains(resp.Stdout, "installed bash completion:") {
		t.Fatalf("stdout missing installed message: %q", resp.Stdout)
	}
	if strings.Contains(resp.Stdout, "updated bash profile:") {
		t.Fatalf("stdout must not report profile update when already sourcing: %q", resp.Stdout)
	}

	content := completionContent(resp.CompletionPath, resp)
	if content == "MISSING" {
		t.Fatalf("expected completion file at %q", resp.CompletionPath)
	}
	if !hasCompletionMarkers(t, content) {
		t.Fatalf("completion content missing expected markers: %q", content)
	}

	assertProfileUnchanged(t, req, resp)

	t.Logf("profile-already-sources OK")
}
```