## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `installed bash completion:` and `updated bash profile:`.
- Bash profile exists and contains `profileSourceSubstring`.
- Bash profile contains `profileSourceMarker` comment.
- Completion file exists with bundled markers.

## Side Effects

- Creates `$HOME/.bash_profile` with agent-sessions source block.

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
	if !strings.Contains(resp.Stdout, "updated bash profile:") {
		t.Fatalf("stdout missing updated bash profile message: %q", resp.Stdout)
	}
	if !strings.Contains(resp.Stdout, resp.ProfilePath) {
		t.Fatalf("stdout missing profile path %q: %q", resp.ProfilePath, resp.Stdout)
	}

	profile := profileContent(resp.ProfilePath, resp)
	if profile == "MISSING" {
		t.Fatalf("expected bash profile to be created at %q", resp.ProfilePath)
	}
	if !profileHasSourceLine(profile) {
		t.Fatalf("profile missing source substring: %q", profile)
	}
	if !strings.Contains(profile, profileSourceMarker) {
		t.Fatalf("profile missing source marker comment: %q", profile)
	}

	content := completionContent(resp.CompletionPath, resp)
	if content == "MISSING" {
		t.Fatalf("expected completion file at %q", resp.CompletionPath)
	}
	if !hasCompletionMarkers(t, content) {
		t.Fatalf("completion content missing expected markers: %q", content)
	}

	t.Logf("profile-append-on-install OK")
}
```