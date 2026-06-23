# UI Testing Guide (macOS)

How we run automated UI tests for SwiftUI windows in this repo, what breaks in practice, and how to fix it.

**Reference implementation:** `macos-agent-sessions/tests/settings-integrations/window/`

---

## Architecture

```
doctest leaf (Go)
  └─ Run() in DOCTEST.md
       └─ pipes JSON → .build/ui-automation-helper (Swift)
            ├─ pre-starts agent-sessions daemon (ephemeral port, fake HOME)
            ├─ launches app with -uiTestingOpenSettings
            ├─ drives AX APIs (open / dump_layout / click)
            └─ prints one JSON Response on stdout
```

| Layer | Role |
|-------|------|
| **doctest tree** | Declares scenarios, assertions, isolation (`fakeHome` under `t.TempDir()`) |
| **Go harness** (`DOCTEST.md`) | Spawns helper, enforces timeout, parses JSON, skips on AX disabled |
| **Swift helper** (`UIAutomationHelper.swift`) | Owns app + daemon lifecycle, AX automation, lock serialization |
| **App** | Test-only launch arg opens target window; must not fight helper for daemon ownership |

Detection/CLI tests in the same tree do **not** need Accessibility or the helper.

---

## Prerequisites

### Accessibility permission

Window tests use `AXUIElement`, `AXPress`, and `CGEvent`. The **test runner process** (Terminal, iTerm, Cursor, `go test`) needs Accessibility:

**System Settings → Privacy & Security → Accessibility**

If missing, the helper returns `kAXErrorAPIDisabled` (`-25211`). The Go harness calls `t.Skip` with a clear message — this is expected, not a product bug.

### Isolation

Every test must use isolated dirs — never the real user home:

- `fakeHome := filepath.Join(t.TempDir(), "home")`
- `t.Setenv("HOME", fakeHome)`
- Daemon state: `<fakeHome>/.os-bar/agent-sessions`
- Ephemeral port per run (never production ports)

### Production app vs test processes

`/Applications/os-bar.app` (menu bar + `os-bar-daemon`) is unrelated to doctest runs. Orphaned **test** processes look like:

```
.build/agent-sessions serve --port … --state-dir …/TestGeneratedCase…
.build/debug/os-bar-agent-sessions -uiTestingOpenSettings
```

---

## Writing a window test

### 1. SwiftUI: expose a stable AX tree

Automation finds nodes by **accessibility identifier**, not visual layout.

```swift
// Parent row: contain children, don't collapse them
.accessibilityElement(children: .contain)
.accessibilityIdentifier("integration-\(item.id)")

// Decorative text: hide from AX
.accessibilityHidden(true)

// Actionable control: explicit button + fallback action
Button("Install") { onInstall() }
    .accessibilityElement()
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("integration-\(item.id)-install")
    .accessibilityAction { onInstall() }  // AXPress alone may not fire SwiftUI actions
```

**Gocha:** `.accessibilityElement()` on a parent row **without** `children: .contain` hides child status/install nodes — `dump_layout` will not see them.

### 2. Test-only app entry point

Use a launch argument to open the window directly (no menu-bar interaction):

```swift
// App launch: -uiTestingOpenSettings
// IntegrationsLauncher waits for DaemonReadiness, then openWindow(id: "integrations")
```

**Gocha:** Opening the window before the daemon is healthy → `refresh()` fails once, UI shows error, AX never sees rows. Fix: wait for `DaemonReadiness` before `refresh()` / `openWindow`, and retry `refresh()` in the view model.

### 3. Daemon ownership in UI-testing mode

The **helper** pre-starts the daemon and passes env to the app:

- `AGENT_SESSIONS_CLI`
- `AGENT_SESSIONS_PORT`
- `AGENT_SESSIONS_STATE_DIR`

The app in `-uiTestingOpenSettings` mode must **only poll health** — never spawn its own daemon. A second, untracked daemon survives teardown and leaks after tests.

### 4. Helper actions

| Action | Purpose |
|--------|---------|
| `open_settings` | Start daemon, launch app, wait for Integrations window |
| `dump_layout` | Snapshot AX tree (`layout`, `layout_before`, `layout_after` in sequences) |
| `click` | Activate app, raise window, `AXPress` + `CGEvent.postToPid`, poll status change |
| `sequence` | Run sub-requests in order |
| `teardown` | Kill app + daemon (including port/state-dir sweep) |

**Every window sequence must end with `teardown`** (or rely on helper `defer`, but explicit is safer):

```go
req.Sequence = []Request{
    {Action: "open_settings"},
    {Action: "dump_layout"},
    {Action: "teardown"},
}
```

### 5. Go harness (`runUIAutomation`)

- Build helper: `swiftc -o .build/ui-automation-helper os-bar-agent-sessionsTests/UIAutomationHelper.swift`
- Write one JSON line to stdin, close stdin
- Read **one** JSON line from stdout
- **30s hard timeout** — on hang, prints debug hints (pipe/stdin, stale PIDs, lock)

### 6. Lock serialization

Window tests share `macos-agent-sessions/.build/ui-automation.lock` (flock). Parallel window leaves queue behind each other — expected. Stale lock after a killed run:

```bash
rm -f macos-agent-sessions/.build/ui-automation.lock
```

---

## Common gochas and fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `go test` hangs forever (~50–90s+) | Spawned app/daemon inherited helper stdout/stderr pipe; runner blocks on `cmd.Wait()` | Redirect child stdout/stderr to `FileHandle.nullDevice` in helper |
| `json.load(stdin)` → EOF / Extra data | Same pipe pollution, or `2>&1` mixing stderr into stdout | Helper: nullDevice for children; Go: only parse helper stdout |
| Test stuck, `lsof -p <helper> \| grep PIPE` shows open pipes | App or daemon still writing to inherited pipe | nullDevice on **both** app and daemon `Process` |
| Layout missing `integration-grok` | Daemon not ready on first `refresh()`, or AX tree collapsed | Daemon readiness gate + `refresh()` retry; `.accessibilityElement(children: .contain)` |
| `AXPress` returns success, status unchanged | SwiftUI `Button` ignores synthetic AX press | `.accessibilityAction`, `CGEvent.postToPid`, activate app + raise window, poll status |
| Install corrupts helper JSON | Daemon install wrote to stdout | Daemon stdout/stderr → nullDevice |
| Orphan `.build/agent-sessions serve` after PASS | App spawned extra daemon, or teardown missed untracked PID | App: no spawn in UI-testing mode; teardown: kill by port + state-dir via `pgrep` |
| Integrations window left open / dock icon | Sequence without `teardown` | Add `teardown` to every sequence; helper `defer { session.teardown() }` |
| Parallel window tests slow (~12s+) | Lock + per-run `go build` / `swiftc` | Normal for cold runs; use doctest cache for iteration; kill stale processes between debug sessions |
| `kAXErrorAPIDisabled` | Accessibility off for test runner | Enable in System Settings; harness skips |
| Daemon from wrong test still running | Prior run killed mid-flight (`SIGKILL` skips `defer`) | Kill stale PIDs before debugging (see below) |

---

## Teardown checklist

Helper `teardown()` should:

1. Kill **child processes** of the app (e.g. app-spawned tools) before killing the app
2. `terminate()` app, then `SIGKILL` if needed
3. Kill tracked daemon `Process`, then sweep `agent-sessions serve` matching **port** and **state-dir**
4. Reset session state (port, PIDs, cached window ref)

App side: in `-uiTestingOpenSettings`, **do not** call `spawnDaemon()` — helper owns the process.

---

## Debugging

### Kill stale test processes

```bash
pgrep -f 'os-bar-agent-sessions -uiTestingOpenSettings' | xargs kill -9
pgrep -f '\.build/agent-sessions serve.*TestGeneratedCase' | xargs kill -9
rm -f macos-agent-sessions/.build/ui-automation.lock
```

### Run one leaf verbosely

```bash
cd macos-agent-sessions
doctest test -count=1 -v ./tests/settings-integrations/window/open/window-visible
```

### Manual helper smoke test

```bash
cd macos-agent-sessions
FAKE_HOME=$(mktemp -d)
printf '{"action":"sequence","home_dir":"%s","work_dir":"%s","sequence":[{"action":"open_settings"},{"action":"dump_layout"},{"action":"teardown"}]}' \
  "$FAKE_HOME" "$FAKE_HOME" | .build/ui-automation-helper | python3 -m json.tool
rm -rf "$FAKE_HOME"
```

Must return **one** JSON object and exit — not hang.

### Pipe hang diagnosis

```bash
lsof -p <helper-pid> | grep PIPE
pgrep -lf 'ui-automation-helper|os-bar-agent-sessions|agent-sessions serve'
```

### Full window suite

```bash
cd macos-agent-sessions
doctest test -count=1 ./tests/settings-integrations/window/...
```

Target: all leaves pass in ~10–15s uncached; **zero** orphan test processes afterward.

---

## Doctest layout rules

- `Request`, `Response`, `Run()` live in **`DOCTEST.md`** (root), not `SETUP.md`
- `SETUP.md` files start with `# Scenario` and describe steps only
- Window harness code belongs in the shared `runUIAutomation()` path, not per-leaf copies

---

## Adding UI tests to a new feature

1. Add accessibility identifiers to SwiftUI views (parent `children: .contain`, hide decorative text).
2. Add a test-only launch path (argument or env) that opens the target window when daemon is ready.
3. Extend or fork `UIAutomationHelper.swift` with actions for that window.
4. Create a doctest `window/` subtree; route window actions through `runUIAutomation()`.
5. End every sequence with `teardown`; set 30s timeout on the helper subprocess.
6. Redirect all spawned process stdout/stderr to nullDevice.
7. Ensure the app does not spawn duplicate background services in test mode.
8. Document AX identifiers in the window `SETUP.md` context section.

---

## Related files

| File | Purpose |
|------|---------|
| `macos-agent-sessions/os-bar-agent-sessionsTests/UIAutomationHelper.swift` | Helper binary source |
| `macos-agent-sessions/tests/settings-integrations/DOCTEST.md` | Go harness, timeout, `runUIAutomation` |
| `macos-agent-sessions/tests/settings-integrations/window/` | Example window test tree |
| `macos-agent-sessions/os-bar-agent-sessions/IntegrationsSettingsView.swift` | AX identifiers + UI-testing hooks |
| `macos-agent-sessions/os-bar-agent-sessions/AgentSessionApp.swift` | `-uiTestingOpenSettings`, daemon readiness |
| `macos/tests/menubar-monitor/` | Legacy Swift `TestHelper` pattern (metrics); backend moved to `go-pkgs/server/tests/` |