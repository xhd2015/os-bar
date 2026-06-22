## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `would install bash completion:` and `resp.CompletionPath`.
- Completion file remains MISSING.

## Side Effects

- No files created under `resp.FakeHome`.

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
	if !strings.Contains(resp.Stdout, "would install bash completion:") {
		t.Fatalf("stdout missing would install message: %q", resp.Stdout)
	}
	if !strings.Contains(resp.Stdout, resp.CompletionPath) {
		t.Fatalf("stdout missing completion path: %q", resp.Stdout)
	}
	if completionContent(resp) != "MISSING" {
		t.Fatalf("dry-run must not create completion file")
	}

	t.Logf("bash-completions-still-works OK")
}
```