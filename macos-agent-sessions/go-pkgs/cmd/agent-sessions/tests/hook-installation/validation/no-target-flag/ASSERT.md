## Expected
- `resp.ExitCode == 1`.
- `resp.Stderr` contains `"at least one of --pi, --opencode, --grok, --codex, or --claude is required"`.
- No files created under `resp.FakeHome` or `resp.WorkDir`.

## Side Effects
- None. Isolated temp dirs remain empty of hook artifacts.

## Exit Code
- `1`

```go
import "strings"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 1 {
		t.Fatalf("expected exit code 1, got %d", resp.ExitCode)
	}
	if !strings.Contains(resp.Stderr, "at least one of --pi, --opencode, --grok, --codex, or --claude is required") {
		t.Fatalf("stderr missing required-flag message: %q", resp.Stderr)
	}
	assertNoFilesUnderDir(t, resp.FakeHome)
	assertNoFilesUnderDir(t, resp.WorkDir)
	t.Logf("no-target-flag OK: exit=%d", resp.ExitCode)
}
```