## Expected
- Grok integration: `status == "up_to_date"`, `scope == "global"`, path under `fakeHome/.grok/hooks/agent-sessions.json`.
- OpenCode, pi, codex: `status == "missing"`.
- All paths under `resp.HomeDir`.

## Side Effects
- Seeded grok files exist at expected paths (not modified by detection scan).

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

	grok := integrationByID(resp.Integrations, "grok")
	if grok == nil {
		t.Fatal("missing grok integration")
	}
	if grok.Status != "up_to_date" {
		t.Fatalf("grok: expected up_to_date, got %q", grok.Status)
	}
	wantGrokPath := filepath.Join(resp.HomeDir, ".grok", "hooks", "agent-sessions.json")
	if grok.Path != wantGrokPath {
		t.Fatalf("grok path: got %q want %q", grok.Path, wantGrokPath)
	}
	assertPathUnderHome(t, grok.Path, resp.HomeDir)

	for _, id := range []string{"opencode", "pi", "codex"} {
		item := integrationByID(resp.Integrations, id)
		if item == nil {
			t.Fatalf("missing integration %q", id)
		}
		if item.Status != "missing" {
			t.Fatalf("%s: expected missing, got %q", id, item.Status)
		}
	}

	t.Logf("detection/grok-installed OK: grok=%s", grok.Path)
}
```