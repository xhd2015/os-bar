## Expected
- Codex integration: `status == "up_to_date"`, path is `fakeHome/.codex/hooks.json`.
- Grok, opencode, pi: `status == "missing"`.
- On-disk `hooks.json` still contains `/bin/other.sh` (foreign UserPromptSubmit) and `/bin/skynet.sh` (foreign Stop).

## Side Effects
- No modification to seeded hooks.json during detection scan.

## Exit Code
- CLI exits 0.

```go
import (
	"os"
	"path/filepath"
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}

	codex := integrationByID(resp.Integrations, "codex")
	if codex == nil {
		t.Fatal("missing codex integration")
	}
	if codex.Status != "up_to_date" {
		t.Fatalf("codex: expected up_to_date, got %q", codex.Status)
	}
	wantCodexPath := filepath.Join(resp.HomeDir, ".codex", "hooks.json")
	if codex.Path != wantCodexPath {
		t.Fatalf("codex path: got %q want %q", codex.Path, wantCodexPath)
	}
	assertPathUnderHome(t, codex.Path, resp.HomeDir)

	for _, id := range []string{"grok", "opencode", "pi"} {
		item := integrationByID(resp.Integrations, id)
		if item == nil {
			t.Fatalf("missing integration %q", id)
		}
		if item.Status != "missing" {
			t.Fatalf("%s: expected missing, got %q", id, item.Status)
		}
	}

	hooksPath := filepath.Join(resp.HomeDir, ".codex", "hooks.json")
	content, err := os.ReadFile(hooksPath)
	if err != nil {
		t.Fatalf("read hooks.json: %v", err)
	}
	text := string(content)
	if !strings.Contains(text, "/bin/other.sh") {
		t.Fatal("foreign UserPromptSubmit command /bin/other.sh removed from hooks.json")
	}
	if !strings.Contains(text, "/bin/skynet.sh") {
		t.Fatal("foreign Stop command /bin/skynet.sh removed from hooks.json")
	}
	if !strings.Contains(text, "skynet stop") {
		t.Fatal("foreign Stop statusMessage removed from hooks.json")
	}

	t.Logf("detection/codex-merged OK: codex=%s", codex.Path)
}
```