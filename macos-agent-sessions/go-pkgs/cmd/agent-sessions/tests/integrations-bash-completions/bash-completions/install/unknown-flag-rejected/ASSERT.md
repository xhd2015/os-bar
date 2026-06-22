## Expected

- `resp.ExitCode == 1`.
- `resp.Stderr` contains `unrecognized flag`.
- No completion file or bash profile created.

## Errors

- CLI rejects `--bogus` before any install logic runs.

## Exit Code

- `1`

```go
import (
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 1 {
		t.Fatalf("expected exit code 1, got %d; stdout=%q stderr=%q", resp.ExitCode, resp.Stdout, resp.Stderr)
	}
	if !strings.Contains(resp.Stderr, "unrecognized flag") {
		t.Fatalf("stderr missing unrecognized flag error: %q", resp.Stderr)
	}
	if completionContent(resp.CompletionPath, resp) != "MISSING" {
		t.Fatalf("unknown flag must not create completion file")
	}
	if profileContent(resp.ProfilePath, resp) != "MISSING" {
		t.Fatalf("unknown flag must not create bash profile")
	}

	t.Logf("unknown-flag-rejected OK")
}
```