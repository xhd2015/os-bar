## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `install →` (reports pending install for grok hook script and/or hooks).
- All grok snapshot paths are `MISSING` — no files created.

## Exit Code

- `0`

```go
import "strings"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 0 {
		t.Fatalf("expected exit code 0, got %d; stderr=%q", resp.ExitCode, resp.Stderr)
	}
	if !strings.Contains(resp.Stdout, "install →") {
		t.Fatalf("stdout missing install report: %q", resp.Stdout)
	}
	assertNoFilesCreated(t, resp)
	t.Logf("grok-dry-run-missing OK")
}
```