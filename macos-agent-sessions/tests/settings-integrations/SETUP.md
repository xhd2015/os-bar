# Scenario

## Preconditions
- The `macos-agent-sessions` Swift package exists with an Integrations settings window (title **Integrations**).
- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")`.
- A Swift UI automation helper is built at `macos-agent-sessions/.build/ui-automation-helper` from `os-bar-agent-sessionsTests/UIAutomationHelper.swift`.
- The app accepts launch argument `-uiTestingOpenSettings` to open the Integrations window directly.
- **Isolation (mandatory):** Every test runs in isolated temporary directories. `Run` sets `HOME` to a dedicated `fakeHome` temp dir (never the real user home). `workDir` is a separate fixture project directory. UI helper and CLI both receive the same `home_dir` / `work_dir`.
- **Accessibility (window tests only):** Window-layer tests require Accessibility permission for the test runner process. If the helper returns `kAXErrorAPIDisabled` (-25211), tests call `t.Skip` with a clear message. Detection tests do not require Accessibility.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps
1. Create `fakeHome := filepath.Join(t.TempDir(), "home")` and `workDir := filepath.Join(t.TempDir(), "proj")`; `MkdirAll` both with mode `0755`.
2. Populate `req.HomeDir` / `req.WorkDir` when empty.
3. Build binaries **before** overriding `HOME` (avoids go telemetry writes into fakeHome).
4. `t.Setenv("HOME", fakeHome)` — required before integration scan or app launch.
5. Apply `req.SeedProfile` fixtures under `fakeHome` only (see seed helpers below).
6. Route by `req.Action`:
   - `integrations_json` — run `agent-sessions integrations --json [--global]`, parse stdout
   - window actions — pipe JSON to `ui-automation-helper` via stdin, parse stdout (30s hard timeout; on hang, prints stdin/pipe debug hints)
7. Return `(*Response, nil)` with `HomeDir` and `WorkDir` populated.

## Context
- Detection layer action: `integrations_json` — machine-readable install status for grok, opencode, pi, codex.
- Window layer actions: `open_settings`, `dump_layout`, `click`, `sequence`, `teardown`, `launch_app`, `click_settings_menu`, `check_window`, `check_window_front`, `obscure_window`.
- `sequence` runs sub-requests in order; first `dump_layout` → `LayoutBefore`, last `dump_layout` → `LayoutAfter`.
- Status JSON enum: `missing` | `installed` | `up_to_date` | `outdated`.
- UI badge title values (v1): `Missing`, `Installed`, `Up to date`, `Outdated`.
- v1 window install scope is global only (`req.Global = true` for click-install leaves).
- Reuses the same content-comparison logic as `install --dry-run` / `checkAndWrite`.
