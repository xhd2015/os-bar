## Expected

- Install POST returns HTTP 200.
- `grok` integration has `status == "up_to_date"`.
- Files exist under `resp.HomeDir`:
  - `.grok/hooks/agent-sessions.json`
  - `.grok/hooks/bin/agent-sessions-stop.sh` (executable)
- All paths under `resp.HomeDir` only (isolation).

## Side Effects

- Grok hook JSON and stop script written to fake HOME.

## Errors

- Missing files or non-executable script fails the test.
- Grok status other than `up_to_date` fails the test.

```go
import (
	"os"
	"path/filepath"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected install HTTP 200, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	grok := integrationByID(resp.Integrations, "grok")
	if grok == nil {
		t.Fatal("expected grok integration in response")
	}
	if grok.Status != "up_to_date" {
		t.Fatalf("expected grok up_to_date, got %q", grok.Status)
	}
	assertPathUnderHome(t, grok.Path, resp.HomeDir)

	jsonPath := filepath.Join(resp.HomeDir, ".grok", "hooks", "agent-sessions.json")
	scriptPath := filepath.Join(resp.HomeDir, ".grok", "hooks", "bin", "agent-sessions-stop.sh")
	for _, p := range []string{jsonPath, scriptPath} {
		assertPathUnderHome(t, p, resp.HomeDir)
		if _, err := os.Stat(p); err != nil {
			t.Fatalf("expected file %q to exist: %v", p, err)
		}
	}
	info, err := os.Stat(scriptPath)
	if err != nil {
		t.Fatalf("stat script: %v", err)
	}
	if info.Mode().Perm()&0111 == 0 {
		t.Fatalf("expected script executable, mode=%v", info.Mode())
	}
	t.Logf("integrations-api/install-grok OK: home=%s", resp.HomeDir)
}
```