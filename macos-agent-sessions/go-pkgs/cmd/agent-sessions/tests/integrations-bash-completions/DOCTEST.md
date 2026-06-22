# Integrations Bash-Completions — Doc-Style Test Tree

Test suite for `agent-sessions integrations` help examples, dual-scope
human-readable default output, the nested `bash-completions` subcommand, bash
completion install/update/dry-run semantics, bash profile sourcing, and
regression of existing `integrations --json` behavior.

All tests run in isolated temporary `HOME` and workspace directories — never
the real user home.

# DSN (Domain Specific Notion)

The **CLI binary** is the entry point. It parses top-level subcommands and
delegates to handlers.

The **integrations handler** serves three modes: printing a human-readable
status table by default (`[--global] [--local]`), listing integration install
status as JSON when `--json` is passed (`--json [--global] [--local]`), or
dispatching to nested subcommands when a positional argument is present
(`bash-completions`).

The **scope resolver** determines which install locations to check. With no
scope flags, both global (`~`) and project-local (`cwd`) paths are included.
`--global` alone checks global paths; `--local` alone checks local paths;
`--global --local` is equivalent to the default.

The **human formatter** renders scope-aware headers and rows. Single-scope
mode uses `Integrations (global):` or `Integrations (local):` with one row per
agent and no scope suffixes. Dual-scope mode uses bare `Integrations:` and
collapses rows when both scopes share the same non-missing status; otherwise
emits global then local rows per agent with `(Global)` / `(Local)` suffixes.

The **bash-completions handler** prints subcommand help when invoked without
`--install`, or installs/updates an embedded completion script and ensures the
user's bash profile sources it when `--install` is given. With `--dry-run`, it
reports the planned file and profile actions without writing.

The **fake HOME** is an isolated temp directory. `HOME` is overridden so install
paths resolve under test control, never touching the real user profile.

The **completion file** lives at
`$HOME/.config/agent-sessions/bash-completion.bash`. Content is embedded in the
binary via `//go:embed` and must register completion for the full
`agent-sessions` command tree.

The **bash profile** is `$HOME/.bash_profile` on macOS bash. Install appends a
marked source block when the profile does not already contain the completion
path substring. If the substring is already present, the profile is left
unchanged (idempotent).

## Decision Tree

```
integrations-bash-completions/              ROOT: Request{Action, JsonOut, Global, Local, ...}
│                                                    Response{ExitCode, Stdout, Files{...}, ...}
│                                                    Run() builds CLI, sets fake HOME, exec binary
│
├── help/                                   DECISION: Action = help scenarios
│   └── [SETUP] grouping for help-only invocations
│   │
│   ├── integrations-help-has-examples/     LEAF: integrations --help
│   │   ├── SETUP → Action=integrations, Args=["--help"]
│   │   ├── ASSERT → exit 0, Examples with dual-scope + --local docs
│   │
│   ├── bash-completions-help-default/      LEAF: integrations bash-completions (bare)
│   │   ├── SETUP → Action=integrations_bash_completions, CaptureHelpReference
│   │   ├── ASSERT → exit 0, help describes ~/.bash_profile direct sourcing
│   │
│   └── bash-completions-help-flag/         LEAF: integrations bash-completions --help
│       ├── SETUP → Action=integrations_bash_completions, Args=["--help"]
│       ├── ASSERT → exit 0, usage/flags/examples, no framework-dir path
│
├── bash-completions/                       DECISION: Action = integrations_bash_completions
│   └── [SETUP] req.Action = integrations_bash_completions
│   │
│   └── install/                            DECISION: --install flag scenarios
│       └── [SETUP] grouping for install/dry-run/profile/error paths
│       │
│       ├── fresh-install/                  LEAF: --install on empty fakeHome
│       ├── profile-append-on-install/      LEAF: missing profile, --install
│       ├── profile-already-sources/        LEAF: profile pre-seeded with source, --install
│       ├── idempotent-reinstall/           LEAF: --install twice
│       ├── update-existing/                LEAF: stale completion + profile already sources
│       ├── dry-run-missing/                LEAF: --install --dry-run, no files
│       ├── dry-run-existing/               LEAF: matching completion, --install --dry-run
│       ├── dry-run-would-update/           LEAF: stale completion, --install --dry-run
│       └── unknown-flag-rejected/          LEAF: --bogus flag
│
├── human-output/                           DECISION: human-readable (JsonOut=false)
│   └── [SETUP] req.Action = integrations
│   │
│   ├── default-both-scopes/                LEAF: integrations (no flags)
│   │   ├── SETUP → default flags
│   │   ├── ASSERT → Integrations: header, 8 Missing rows with suffixes
│   │
│   ├── local-only/                         LEAF: integrations --local
│   │   ├── SETUP → Local=true
│   │   ├── ASSERT → Integrations (local):, 4 rows, no suffixes
│   │
│   ├── global-only/                        LEAF: integrations --global
│   │   ├── SETUP → Global=true
│   │   ├── ASSERT → Integrations (global):, 4 rows, no suffixes
│   │
│   ├── both-flags-same-as-default/         LEAF: integrations --global --local
│   │   ├── SETUP → Global=true, Local=true
│   │   ├── ASSERT → same as default-both-scopes
│   │
│   ├── all-missing-global/                 LEAF: empty fakeHome + --global
│   │   ├── SETUP → Global=true
│   │   ├── ASSERT → all four rows Missing, no suffixes
│   │
│   ├── status-labels-global/               LEAF: grok installed + --global
│   │   ├── SETUP → Global=true, SeedGrokViaInstall=true
│   │   ├── ASSERT → grok Up to date, others Missing
│   │
│   ├── global-plus-local-installed/        LEAF: grok global+local seeded
│   │   ├── SETUP → SeedGrokViaInstall + SeedGrokLocal
│   │   ├── ASSERT → grok collapsed Up to date (Global + Local)
│   │
│   ├── mixed-scopes/                       LEAF: grok global only seeded
│   │   ├── SETUP → SeedGrokViaInstall=true
│   │   ├── ASSERT → grok Up to date (Global) + Missing (Local)
│   │
│   ├── json-both-scopes/                   LEAF: integrations --json
│   │   ├── SETUP → JsonOut=true
│   │   ├── ASSERT → 8 entries, global+local scopes
│   │
│   ├── json-local-only/                    LEAF: integrations --json --local
│   │   ├── SETUP → JsonOut=true, Local=true
│   │   ├── ASSERT → 4 entries, scope=local
│   │
│   └── json-still-works/                   LEAF: integrations --json --global
│       ├── SETUP → JsonOut=true, Global=true
│       ├── ASSERT → valid JSON with 4 integrations
│
└── routing/                                DECISION: integrations JSON regression
    └── [SETUP] req.Action = integrations, JsonOut=true
    │
    └── integrations-json-unchanged/        LEAF: integrations --json --global
        ├── SETUP → Global=true
        ├── ASSERT → exit 0, valid JSON with 4 integrations
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `help/integrations-help-has-examples/` | `integrations --help` documents dual-scope default and `--local` |
| 2 | `help/bash-completions-help-default/` | Bare `bash-completions` prints help with direct profile sourcing |
| 3 | `help/bash-completions-help-flag/` | `bash-completions --help` shows usage, flags, examples |
| 4 | `bash-completions/install/fresh-install/` | Fresh `--install` creates completion + appends profile source |
| 5 | `bash-completions/install/profile-append-on-install/` | Missing profile gains source block on install |
| 6 | `bash-completions/install/profile-already-sources/` | Pre-sourced profile left byte-identical on install |
| 7 | `bash-completions/install/idempotent-reinstall/` | Second `--install` reports up to date, profile not duplicated |
| 8 | `bash-completions/install/update-existing/` | Stale completion updated; profile untouched |
| 9 | `bash-completions/install/dry-run-missing/` | Dry-run reports would install; no file writes |
| 10 | `bash-completions/install/dry-run-existing/` | Dry-run on matching file reports up to date |
| 11 | `bash-completions/install/dry-run-would-update/` | Dry-run on stale file reports would update |
| 12 | `bash-completions/install/unknown-flag-rejected/` | Unknown flag exits 1 with error |
| 13 | `human-output/default-both-scopes/` | `integrations` prints dual-scope human table (default) |
| 14 | `human-output/local-only/` | `integrations --local` prints local human table |
| 15 | `human-output/global-only/` | `integrations --global` prints global human table |
| 16 | `human-output/both-flags-same-as-default/` | `--global --local` same as default |
| 17 | `human-output/all-missing-global/` | Empty HOME + `--global` → all `Missing`, no suffixes |
| 18 | `human-output/status-labels-global/` | Seeded grok → `Up to date`, others `Missing` |
| 19 | `human-output/global-plus-local-installed/` | Grok both scopes → collapsed `(Global + Local)` row |
| 20 | `human-output/mixed-scopes/` | Grok global only → split global/local rows |
| 21 | `human-output/json-both-scopes/` | `--json` returns 8 global+local entries |
| 22 | `human-output/json-local-only/` | `--json --local` returns 4 local entries |
| 23 | `human-output/json-still-works/` | `--json --global` JSON regression from human-output branch |
| 24 | `routing/integrations-json-unchanged/` | `integrations --json --global` unchanged |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Integrations help dual-scope + --local | `integrations-help-has-examples` | ✓ |
| Bash-completions default help | `bash-completions-help-default` | ✓ |
| Bash-completions --help flag | `bash-completions-help-flag` | ✓ |
| Fresh completion + profile install | `fresh-install` | ✓ |
| Profile append on missing profile | `profile-append-on-install` | ✓ |
| Profile skip when already sources | `profile-already-sources` | ✓ |
| Idempotent reinstall | `idempotent-reinstall` | ✓ |
| Update stale completion | `update-existing` | ✓ |
| Dry-run missing files | `dry-run-missing` | ✓ |
| Dry-run matching file | `dry-run-existing` | ✓ |
| Dry-run would update | `dry-run-would-update` | ✓ |
| Unknown flag rejection | `unknown-flag-rejected` | ✓ |
| Default dual-scope human table | `default-both-scopes` | ✓ |
| Human table local only | `local-only` | ✓ |
| Human table global only | `global-only` | ✓ |
| Both scope flags = default | `both-flags-same-as-default` | ✓ |
| All missing human labels (global) | `all-missing-global` | ✓ |
| Mixed human status labels (global) | `status-labels-global` | ✓ |
| Collapsed dual-scope row | `global-plus-local-installed` | ✓ |
| Split dual-scope rows | `mixed-scopes` | ✓ |
| JSON both scopes (8 entries) | `json-both-scopes` | ✓ |
| JSON local only (4 entries) | `json-local-only` | ✓ |
| JSON path --global regression | `json-still-works` | ✓ |
| Integrations JSON routing regression | `integrations-json-unchanged` | ✓ |

## How to Run

```sh
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest vet ./tests/integrations-bash-completions
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/integrations-bash-completions
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test -v ./tests/integrations-bash-completions/...
```