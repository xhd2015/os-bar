## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `would update bash completion:`.
- Completion file still contains stale `_stale` marker (not overwritten).
- Bash profile remains MISSING (no profile pre-seed).

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
	if !strings.Contains(resp.Stdout, "would update bash completion:") {
		t.Fatalf("stdout missing would update message: %q", resp.Stdout)
	}
	if strings.Contains(resp.Stdout, "would update bash profile:") {
		t.Fatalf("dry-run must not plan profile update when profile is missing: %q", resp.Stdout)
	}

	content := completionContent(resp.CompletionPath, resp)
	if content == "MISSING" {
		t.Fatalf("expected stale completion file to exist")
	}
	if !strings.Contains(content, "_stale") {
		t.Fatalf("dry-run must not overwrite stale content; got %q", content)
	}
	if profileContent(resp.ProfilePath, resp) != "MISSING" {
		t.Fatalf("dry-run must not create bash profile")
	}

	t.Logf("dry-run-would-update OK")
}
```