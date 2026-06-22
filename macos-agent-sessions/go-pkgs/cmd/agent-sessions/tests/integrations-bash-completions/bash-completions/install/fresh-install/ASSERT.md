## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `installed bash completion:` and `resp.CompletionPath`.
- `resp.Stdout` contains `updated bash profile:` and `resp.ProfilePath`.
- Completion file exists at `resp.CompletionPath` under `resp.FakeHome`.
- Bash profile exists at `resp.ProfilePath` and contains `profileSourceSubstring`.
- File content includes `agent-sessions` and top-level subcommand markers.

## Side Effects

- Creates `$HOME/.config/agent-sessions/bash-completion.bash`.
- Creates or updates `$HOME/.bash_profile` with the agent-sessions source block.

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
	if !strings.Contains(resp.Stdout, resp.CompletionPath) {
		t.Fatalf("stdout missing completion path %q: %q", resp.CompletionPath, resp.Stdout)
	}
	if !strings.Contains(resp.Stdout, "updated bash profile:") {
		t.Fatalf("stdout missing updated bash profile message: %q", resp.Stdout)
	}
	if !strings.Contains(resp.Stdout, resp.ProfilePath) {
		t.Fatalf("stdout missing profile path %q: %q", resp.ProfilePath, resp.Stdout)
	}

	assertPathUnderFakeHome(t, resp.CompletionPath, resp.FakeHome)
	assertPathUnderFakeHome(t, resp.ProfilePath, resp.FakeHome)

	content := completionContent(resp.CompletionPath, resp)
	if content == "MISSING" {
		t.Fatalf("expected completion file at %q", resp.CompletionPath)
	}
	if !hasCompletionMarkers(t, content) {
		t.Fatalf("completion content missing expected markers: %q", content)
	}

	profile := profileContent(resp.ProfilePath, resp)
	if profile == "MISSING" {
		t.Fatalf("expected bash profile at %q", resp.ProfilePath)
	}
	if !profileHasSourceLine(profile) {
		t.Fatalf("profile missing source substring: %q", profile)
	}
	if !strings.Contains(profile, profileSourceMarker) {
		t.Fatalf("profile missing source marker comment: %q", profile)
	}

	t.Logf("fresh-install OK: completion=%s profile=%s", resp.CompletionPath, resp.ProfilePath)
}
```