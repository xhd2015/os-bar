## Expected

- `resp.ExitCode == 1`.
- `resp.Stderr` contains `unrecognized flag`.
- No codex files created under `resp.FakeHome` or `resp.WorkDir`.

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

	assertNoFilesCreated(t, resp)

	t.Logf("codex-unknown-flag-rejected OK")
}
```