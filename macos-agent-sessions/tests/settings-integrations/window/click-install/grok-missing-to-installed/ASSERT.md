---
label: ui-automation, slow, requires-accessibility
explanation: AX-clicks grok Install button and verifies status Missing to Up to date plus hook files under fakeHome/.grok/.
---

## Expected
- `resp.ClickOK == true` for grok install click.
- `layout_before`: `integration-grok-status` title `Missing`; `integration-grok-install` present.
- `layout_after`: `integration-grok-status` title `Up to date`; `integration-grok-install` absent.

## Side Effects
- `fakeHome/.grok/hooks/agent-sessions.json` exists after install.
- `fakeHome/.grok/hooks/bin/agent-sessions-stop.sh` exists after install.
- No files written outside `resp.HomeDir`.

## Errors
- If click fails (`click_ok == false`), test fails.
- If status does not transition Missing → Up to date, test fails.

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
		t.Fatal("expected click_ok=true for grok install button")
	}
	if resp.LayoutBefore == nil || resp.LayoutAfter == nil {
		t.Fatal("expected layout_before and layout_after from sequence")
	}

	beforeStatus := findByIdentifier(resp.LayoutBefore, "integration-grok-status")
	if beforeStatus == nil || beforeStatus.Title != "Missing" {
		t.Fatalf("before: grok status expected Missing, got %+v", beforeStatus)
	}
	if findByIdentifier(resp.LayoutBefore, "integration-grok-install") == nil {
		t.Fatal("before: expected integration-grok-install button")
	}

	afterStatus := findByIdentifier(resp.LayoutAfter, "integration-grok-status")
	if afterStatus == nil || afterStatus.Title != "Up to date" {
		t.Fatalf("after: grok status expected Up to date, got %+v", afterStatus)
	}
	if findByIdentifier(resp.LayoutAfter, "integration-grok-install") != nil {
		t.Fatal("after: integration-grok-install should be gone when up to date")
	}

	jsonPath := filepath.Join(resp.HomeDir, ".grok", "hooks", "agent-sessions.json")
	scriptPath := filepath.Join(resp.HomeDir, ".grok", "hooks", "bin", "agent-sessions-stop.sh")
	for _, p := range []string{jsonPath, scriptPath} {
		assertPathUnderHome(t, p, resp.HomeDir)
		if _, err := os.Stat(p); err != nil {
			t.Fatalf("expected file %q after install: %v", p, err)
		}
	}

	t.Logf("window/click-install/grok-missing-to-installed OK")
}
```