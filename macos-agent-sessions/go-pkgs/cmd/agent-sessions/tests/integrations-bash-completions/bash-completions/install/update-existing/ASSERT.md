## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `updated bash completion:`.
- `resp.Stdout` does not contain `updated bash profile:`.
- Completion file no longer contains stale marker `_stale`.
- File content matches bundled completion markers.
- Bash profile content is byte-identical to pre-seeded profile.

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
	if !strings.Contains(resp.Stdout, "updated bash completion:") {
		t.Fatalf("stdout missing updated message: %q", resp.Stdout)
	}
	if strings.Contains(resp.Stdout, "updated bash profile:") {
		t.Fatalf("stdout must not report profile update when already sourcing: %q", resp.Stdout)
	}

	content := completionContent(resp.CompletionPath, resp)
	if content == "MISSING" {
		t.Fatalf("expected completion file after update")
	}
	if strings.Contains(content, "_stale") {
		t.Fatalf("stale content was not replaced: %q", content)
	}
	if !hasCompletionMarkers(t, content) {
		t.Fatalf("updated content missing bundled markers: %q", content)
	}

	assertProfileUnchanged(t, req, resp)

	t.Logf("update-existing OK")
}
```