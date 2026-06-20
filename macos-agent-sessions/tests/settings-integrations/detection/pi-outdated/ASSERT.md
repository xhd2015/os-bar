## Expected
- Pi integration: `status == "outdated"`, path under `fakeHome/.pi/agent/extensions/agent-sessions-hook.ts`.
- Grok, opencode, codex: `status == "missing"`.

## Exit Code
- CLI exits 0.

```go
import (
	"path/filepath"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}

	pi := integrationByID(resp.Integrations, "pi")
	if pi == nil {
		t.Fatal("missing pi integration")
	}
	if pi.Status != "outdated" {
		t.Fatalf("pi: expected outdated, got %q", pi.Status)
	}
	wantPiPath := filepath.Join(resp.HomeDir, ".pi", "agent", "extensions", "agent-sessions-hook.ts")
	if pi.Path != wantPiPath {
		t.Fatalf("pi path: got %q want %q", pi.Path, wantPiPath)
	}
	assertPathUnderHome(t, pi.Path, resp.HomeDir)

	for _, id := range []string{"grok", "opencode", "codex"} {
		item := integrationByID(resp.Integrations, id)
		if item == nil {
			t.Fatalf("missing integration %q", id)
		}
		if item.Status != "missing" {
			t.Fatalf("%s: expected missing, got %q", id, item.Status)
		}
	}

	t.Logf("detection/pi-outdated OK: pi=%s status=%s", pi.Path, pi.Status)
}
```