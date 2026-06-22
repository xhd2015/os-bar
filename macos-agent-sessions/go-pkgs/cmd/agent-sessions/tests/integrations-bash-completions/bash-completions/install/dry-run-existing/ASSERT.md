## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `up to date` and `dry-run`.
- Completion file exists with bundled markers (unchanged).
- Bash profile from seed install is unchanged (contains source substring).

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
	if !strings.Contains(resp.Stdout, "up to date") {
		t.Fatalf("stdout missing up to date message: %q", resp.Stdout)
	}
	if !strings.Contains(resp.Stdout, "dry-run") {
		t.Fatalf("stdout missing dry-run marker: %q", resp.Stdout)
	}
	if strings.Contains(resp.Stdout, "would update bash profile:") {
		t.Fatalf("dry-run on matching file must not plan profile update: %q", resp.Stdout)
	}

	content := completionContent(resp.CompletionPath, resp)
	if content == "MISSING" {
		t.Fatalf("expected seeded completion file to exist")
	}
	if !hasCompletionMarkers(t, content) {
		t.Fatalf("seeded content missing bundled markers")
	}

	profile := profileContent(resp.ProfilePath, resp)
	if profile == "MISSING" {
		t.Fatalf("expected profile from seed install to exist")
	}
	if !profileHasSourceLine(profile) {
		t.Fatalf("seeded profile missing source substring: %q", profile)
	}

	t.Logf("dry-run-existing OK")
}
```