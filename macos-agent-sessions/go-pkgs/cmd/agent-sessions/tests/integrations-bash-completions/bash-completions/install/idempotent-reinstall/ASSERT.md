## Expected

- `resp.ExitCode == 0`.
- `resp.StdoutSecond` contains `up to date`.
- Completion file exists and content is unchanged after second run.
- Bash profile contains exactly one source marker block (not duplicated on second run).

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
	if !strings.Contains(resp.StdoutSecond, "up to date") {
		t.Fatalf("second run stdout missing 'up to date': %q", resp.StdoutSecond)
	}

	content := completionContent(resp.CompletionPath, resp)
	if content == "MISSING" {
		t.Fatalf("expected completion file after idempotent install")
	}
	if !hasCompletionMarkers(t, content) {
		t.Fatalf("completion content missing markers after idempotent install")
	}

	profile := profileContent(resp.ProfilePath, resp)
	if profile == "MISSING" {
		t.Fatalf("expected bash profile after idempotent install")
	}
	if !profileHasSourceLine(profile) {
		t.Fatalf("profile missing source substring after idempotent install: %q", profile)
	}
	if strings.Count(profile, profileSourceMarker) != 1 {
		t.Fatalf("profile must contain exactly one source marker block, got %d in %q", strings.Count(profile, profileSourceMarker), profile)
	}

	t.Logf("idempotent-reinstall OK: second_stdout=%q", resp.StdoutSecond)
}
```