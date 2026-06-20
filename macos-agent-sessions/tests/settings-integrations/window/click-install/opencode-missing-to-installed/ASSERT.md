## Expected
- `resp.ClickOK == true` for opencode install click.
- `layout_before`: `integration-opencode-status` title `Missing`; `integration-opencode-install` present.
- `layout_after`: `integration-opencode-status` title `Up to date`; `integration-opencode-install` absent.

## Side Effects
- `fakeHome/.config/opencode/plugins/agent-sessions.ts` exists after install.
- No files written outside `resp.HomeDir`.

```go
import (
	"os"
	"path/filepath"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if !resp.ClickOK {
		t.Fatal("expected click_ok=true for opencode install button")
	}
	if resp.LayoutBefore == nil || resp.LayoutAfter == nil {
		t.Fatal("expected layout_before and layout_after from sequence")
	}

	beforeStatus := findByIdentifier(resp.LayoutBefore, "integration-opencode-status")
	if beforeStatus == nil || beforeStatus.Title != "Missing" {
		t.Fatalf("before: opencode status expected Missing, got %+v", beforeStatus)
	}
	if findByIdentifier(resp.LayoutBefore, "integration-opencode-install") == nil {
		t.Fatal("before: expected integration-opencode-install button")
	}

	afterStatus := findByIdentifier(resp.LayoutAfter, "integration-opencode-status")
	if afterStatus == nil || afterStatus.Title != "Up to date" {
		t.Fatalf("after: opencode status expected Up to date, got %+v", afterStatus)
	}
	if findByIdentifier(resp.LayoutAfter, "integration-opencode-install") != nil {
		t.Fatal("after: integration-opencode-install should be gone when up to date")
	}

	pluginPath := filepath.Join(resp.HomeDir, ".config", "opencode", "plugins", "agent-sessions.ts")
	assertPathUnderHome(t, pluginPath, resp.HomeDir)
	if _, err := os.Stat(pluginPath); err != nil {
		t.Fatalf("expected opencode plugin at %q: %v", pluginPath, err)
	}

	t.Logf("window/click-install/opencode-missing-to-installed OK")
}
```