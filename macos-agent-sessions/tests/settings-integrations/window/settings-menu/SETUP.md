# Scenario

**Feature**: menu-bar Settings interaction via normal launch (no test auto-open flag)

```
# user launches app normally; menu bar extra appears
launch_app (no -uiTestingOpenSettings) -> MenuBarExtra -> daemon ready

# user opens Settings from menu bar extra
MenuBarExtra -> click Settings… -> Integrations window

# repeat click brings obscured window forward
Integrations window <- obscure_window <- click Settings… (AXMain + app frontmost)
```

## Preconditions
- App must launch **without** `-uiTestingOpenSettings` (normal user launch path).
- Daemon must become healthy before menu interaction.
- Accessibility permission required for menu bar extra and window AX queries.

## Steps
1. `settings-menu` leaves use `launch_app` instead of `open_settings`.
2. Menu interaction via `click_settings_menu` (AX: menu bar extra → **Settings…**).
3. Window state via `check_window` / `check_window_front` without requiring layout dump.
4. `obscure_window` lowers Integrations via AX only (`kAXLowerAction`); must not activate another app.

## Context
- Empty `fakeHome` for all settings-menu leaves.
- Existing `-uiTestingOpenSettings` / `open_settings` path unchanged for other window leaves.
- Window title: **Integrations**; menu item title: **Settings…** (ellipsis character).

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedProfile = ""
	t.Logf("window/settings-menu: normal launch without -uiTestingOpenSettings")
	return nil
}
```