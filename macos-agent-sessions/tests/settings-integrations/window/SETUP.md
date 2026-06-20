## Preconditions
- **Accessibility permission required:** Window tests use macOS Accessibility APIs (`AXUIElement`, `AXPress` / `CGEvent`). The test runner process must have Accessibility enabled in System Settings → Privacy & Security → Accessibility.
- If the UI automation helper returns error containing `kAXErrorAPIDisabled` (-25211), `Run` calls `t.Skip` with message: `Accessibility API disabled (kAXErrorAPIDisabled); enable Accessibility for test runner`.
- App is launched fresh per test with `-uiTestingOpenSettings` and `HOME=<fakeHome>`.
- `teardown` terminates the test app instance after each leaf (via helper or sequence tail).

## Steps
1. Window leaves use `ui-automation-helper` actions: `open_settings`, `dump_layout`, `click`, `sequence`, `teardown`.
2. Empty `fakeHome` unless a leaf seeds fixtures (click-install leaves start from missing state).
3. `req.Global = true` for click-install leaves (v1 global-only install from UI).

## Context
- Window title: **Integrations**.
- Root accessibility identifier: `integrations-window`.
- Row identifiers: `integration-grok`, `integration-opencode`, `integration-pi`, `integration-codex`.
- Status badge identifiers: `integration-*-status` with title values `Missing`, `Installed`, `Up to date`, `Outdated`.
- Install button identifiers: `integration-*-install` (role `AXButton` when visible).
- Install button triggers `agent-sessions install --<target> --global` under isolated `HOME`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Global = true
	return nil
}
```