# Settings Integrations — Doc-Style Test Tree

Test suite for the **Integrations** settings window and `agent-sessions integrations --json`
detection command. Covers machine-readable install status (detection layer) and
accessibility layout capture with real click interactions (window layer).

Install/write logic is covered separately by `go-pkgs/cmd/agent-sessions/tests/hook-installation/`.
This suite focuses on status detection and UI presentation.

## Decision Tree

```
settings-integrations/                    ROOT: Request{Action, HomeDir, ...}, Response{Integrations, Layout, ...}
│                                                    Run() → CLI or UIAutomationHelper via stdin/stdout
│
├── detection/                            DECISION: layer = detection (no UI)
│   └── [SETUP] req.Action = integrations_json, req.Global = true
│   │
│   ├── all-missing/                      LEAF: empty fakeHome
│   │   ├── SETUP → SeedProfile = ""
│   │   └── ASSERT → 4 entries, all status missing, paths under fakeHome
│   │
│   ├── grok-installed/                   LEAF: bundled grok hooks seeded
│   │   ├── SETUP → SeedProfile = grok-installed
│   │   └── ASSERT → grok up_to_date, others missing
│   │
│   ├── pi-outdated/                      LEAF: pi file with wrong bytes
│   │   ├── SETUP → SeedProfile = pi-outdated
│   │   └── ASSERT → pi outdated, others missing
│   │
│   └── codex-merged/                     LEAF: foreign + our hooks merged
│       ├── SETUP → SeedProfile = codex-merged
│       └── ASSERT → codex up_to_date, foreign paths preserved in hooks.json
│
└── window/                               DECISION: layer = window (AX automation)
    └── [SETUP] req.Global = true; skip if kAXErrorAPIDisabled (-25211)
    │
    ├── open/                             DECISION: open Integrations window
    │   └── window-visible/               LEAF: -uiTestingOpenSettings entry
    │       ├── SETUP → sequence: open_settings → dump_layout
    │       └── ASSERT → window_open, integrations-window + 4 row ids
    │
    ├── layout/                           DECISION: badge + button layout
    │   └── all-missing-badges/           LEAF: empty HOME presentation
    │       ├── SETUP → sequence: open_settings → dump_layout
    │       └── ASSERT → each *-status Missing, each *-install AXButton
    │
    └── click-install/                    DECISION: install via UI click
        ├── grok-missing-to-installed/    LEAF: grok Install button
        │   ├── SETUP → sequence: open → dump → click grok-install → dump → teardown
        │   └── ASSERT → Missing→Up to date, hook files under fakeHome/.grok/
        │
        └── opencode-missing-to-installed/ LEAF: opencode Install button
            ├── SETUP → sequence: open → dump → click opencode-install → dump → teardown
            └── ASSERT → Missing→Up to date, plugin under fakeHome/.config/opencode/
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Layer | `detection` (CLI) vs `window` (AX UI) |
| 2 | Seed profile / HOME state | empty, grok-installed, pi-outdated, codex-merged |
| 3 | Window action | open, layout dump, click-install target |
| 4 | Scope | global only (v1) |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `detection/all-missing/` | Empty fakeHome → 4 integrations all `missing` |
| 2 | `detection/grok-installed/` | Seeded grok hooks → grok `up_to_date`, others `missing` |
| 3 | `detection/pi-outdated/` | Seeded wrong pi bytes → pi `outdated`, others `missing` |
| 4 | `detection/codex-merged/` | Merged hooks.json → codex `up_to_date`, foreign hooks preserved |
| 5 | `window/open/window-visible/` | `-uiTestingOpenSettings` opens window with 4 row identifiers |
| 6 | `window/layout/all-missing-badges/` | All status badges `Missing`, all install buttons present |
| 7 | `window/click-install/grok-missing-to-installed/` | Click grok Install → Up to date + files written |
| 8 | `window/click-install/opencode-missing-to-installed/` | Click opencode Install → Up to date + plugin written |

## Coverage Map

| Scenario | Leaf | Layer |
|----------|------|-------|
| All integrations missing (JSON) | `detection/all-missing` | detection |
| Grok up-to-date detection | `detection/grok-installed` | detection |
| Pi outdated detection | `detection/pi-outdated` | detection |
| Codex merge preservation | `detection/codex-merged` | detection |
| Window opens via test arg | `window/open/window-visible` | window |
| Missing badges + install buttons | `window/layout/all-missing-badges` | window |
| Grok install click transition | `window/click-install/grok-missing-to-installed` | window |
| OpenCode install click transition | `window/click-install/opencode-missing-to-installed` | window |

## Isolation

Every test creates `fakeHome` and `workDir` under `t.TempDir()`, sets `HOME=fakeHome`,
and never touches the real user home. Window helper receives the same dirs in `Request`.

## How to Run

```sh
# Vet test tree structure
cd /Users/xhd2015/Projects/xhd2015/os-bar/macos-agent-sessions
doctest vet ./tests/settings-integrations

# Run all tests (expected RED until implementation)
doctest test ./tests/settings-integrations

# Run detection only (no Accessibility required)
doctest test ./tests/settings-integrations/detection/...

# Run window only (requires Accessibility for test runner)
doctest test ./tests/settings-integrations/window/...

# Verbose
doctest test -v ./tests/settings-integrations/...
```