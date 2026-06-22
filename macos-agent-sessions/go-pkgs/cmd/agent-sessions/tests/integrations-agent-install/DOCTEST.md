# Integrations Agent Install — Doc-Style Test Tree

Test suite for nested `integrations` subcommands (`codex`, `grok`, `pi`,
`opencode`) with `--install`, `--dry-run`, and `--global` flags. Validates CLI
routing to existing install logic, help text, regression of `integrations --json`
and `bash-completions`, and per-agent install/dry-run smoke tests.

All tests run in isolated temporary `HOME` and workspace directories — never
the real user home.

# DSN (Domain Specific Notion)

The **CLI binary** is the entry point. It parses `integrations` and dispatches
to nested subcommand handlers when a positional argument is present.

The **integrations handler** serves three modes: human-readable status table
(default), JSON listing when `--json` is passed, or nested subcommand dispatch
(`bash-completions`, `codex`, `grok`, `pi`, `opencode`).

Each **agent subcommand handler** prints subcommand-specific help when invoked
without `--install`, or delegates to existing install logic when `--install` is
given. With `--dry-run`, install reports planned actions without writing files.
With `--global`, install targets the same global paths as `agent-sessions install
--<agent> --global`.

The **install logic** (`InstallCodex`, `InstallGrok`, `CheckAndWrite`) writes
agent-specific hook/config files and scripts under project-local (`workDir`) or
global (`fakeHome`) locations. Codex merge semantics are unchanged and tested
elsewhere.

The **fake HOME** is an isolated temp directory. `HOME` is overridden so global
install paths resolve under test control, never touching the real user profile.

The **workDir** is a separate isolated project directory used as `cmd.Dir` for
local installs.

## Decision Tree

```
integrations-agent-install/                 ROOT: Request{Action, Agent, Install, Global, ...}
│                                                    Response{ExitCode, Stdout, Files, FakeHome, WorkDir, ...}
│                                                    Run() builds CLI, sets fake HOME, exec binary
│
├── help/                                   DECISION: help-only invocations
│   └── [SETUP] grouping for integrations and agent subcommand help
│   │
│   ├── integrations-help-has-agent-example/ LEAF: integrations --help
│   │   ├── SETUP → Action=integrations, Args=["--help"]
│   │   ├── ASSERT → exit 0, Examples includes generic agent install line
│   │
│   ├── codex-help-default/                 LEAF: integrations codex (bare)
│   │   ├── SETUP → Action=integrations_agent, Agent=codex, CaptureHelpReference
│   │   ├── ASSERT → exit 0, help describes --install/--dry-run/--global
│   │
│   └── codex-help-flag/                    LEAF: integrations codex --help
│       ├── SETUP → Action=integrations_agent, Agent=codex, Args=["--help"]
│       ├── ASSERT → exit 0, same help via flag
│
├── routing/                                DECISION: regression guards
│   └── [SETUP] req.Action = integrations or bash-completions routing
│   │
│   ├── integrations-json-unchanged/        LEAF: integrations --json --global
│   │   ├── SETUP → Action=integrations, JsonOut=true, Global=true
│   │   ├── ASSERT → exit 0, valid JSON with 4 integrations
│   │
│   └── bash-completions-still-works/       LEAF: integrations bash-completions --install --dry-run
│       ├── SETUP → Action=integrations_bash_completions, Install=true, DryRun=true
│       ├── ASSERT → exit 0, would-install message, no writes
│
├── codex/                                  DECISION: Agent = codex
│   └── [SETUP] req.Agent = "codex"
│   │
│   └── install/                            DECISION: --install flag scenarios
│       └── [SETUP] grouping for codex install/dry-run/global/error paths
│       │
│       ├── dry-run-missing/                LEAF: codex --install --dry-run
│       │   ├── SETUP → Install=true, DryRun=true
│       │   ├── ASSERT → exit 0, codex install report, hooks.json MISSING
│       │
│       ├── fresh-install-local/            LEAF: codex --install (local)
│       │   ├── SETUP → Install=true, Global=false
│       │   ├── ASSERT → hooks.json + script under workDir with correct content
│       │
│       ├── fresh-install-global/           LEAF: codex --install --global
│       │   ├── SETUP → Install=true, Global=true
│       │   ├── ASSERT → files under fakeHome only, not workDir
│       │
│       └── unknown-flag-rejected/          LEAF: codex --bogus
│           ├── SETUP → Args=["--bogus"]
│           ├── ASSERT → exit 1, stderr unrecognized flag
│
├── grok/                                   DECISION: Agent = grok
│   └── [SETUP] req.Agent = "grok"
│   │
│   └── install/
│       └── dry-run-missing/                LEAF: grok --install --dry-run
│           ├── SETUP → Install=true, DryRun=true
│           ├── ASSERT → exit 0, install report, no files created
│
├── pi/                                     DECISION: Agent = pi
│   └── [SETUP] req.Agent = "pi"
│   │
│   └── install/
│       └── dry-run-missing/                LEAF: pi --install --dry-run
│           ├── SETUP → Install=true, DryRun=true
│           ├── ASSERT → exit 0, pi extension install report, no files
│
└── opencode/                               DECISION: Agent = opencode
    └── [SETUP] req.Agent = "opencode"
    │
    └── install/
        └── dry-run-missing/                LEAF: opencode --install --dry-run
            ├── SETUP → Install=true, DryRun=true
            ├── ASSERT → exit 0, opencode plugin install report, no files
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `help/integrations-help-has-agent-example/` | `integrations --help` includes generic agent install example |
| 2 | `help/codex-help-default/` | Bare `integrations codex` prints subcommand help |
| 3 | `help/codex-help-flag/` | `integrations codex --help` matches bare help |
| 4 | `routing/integrations-json-unchanged/` | `integrations --json --global` unchanged |
| 5 | `routing/bash-completions-still-works/` | `bash-completions --install --dry-run` still works |
| 6 | `codex/install/dry-run-missing/` | Codex dry-run reports install, no hooks.json |
| 7 | `codex/install/fresh-install-local/` | Codex local install creates hooks.json + script |
| 8 | `codex/install/fresh-install-global/` | Codex global install under fakeHome only |
| 9 | `codex/install/unknown-flag-rejected/` | Unknown flag on codex subcommand exits 1 |
| 10 | `grok/install/dry-run-missing/` | Grok dry-run smoke test |
| 11 | `pi/install/dry-run-missing/` | Pi dry-run smoke test |
| 12 | `opencode/install/dry-run-missing/` | OpenCode dry-run smoke test |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Integrations help agent example | `integrations-help-has-agent-example` | ✓ |
| Codex default help | `codex-help-default` | ✓ |
| Codex --help flag | `codex-help-flag` | ✓ |
| Integrations JSON routing regression | `integrations-json-unchanged` | ✓ |
| Bash-completions routing regression | `bash-completions-still-works` | ✓ |
| Codex dry-run (no write) | `codex/install/dry-run-missing` | ✓ |
| Codex fresh local install | `codex/install/fresh-install-local` | ✓ |
| Codex fresh global install | `codex/install/fresh-install-global` | ✓ |
| Codex unknown flag rejection | `codex/install/unknown-flag-rejected` | ✓ |
| Grok routing + dry-run smoke | `grok/install/dry-run-missing` | ✓ |
| Pi routing + dry-run smoke | `pi/install/dry-run-missing` | ✓ |
| OpenCode routing + dry-run smoke | `opencode/install/dry-run-missing` | ✓ |

## How to Run

```sh
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest vet ./tests/integrations-agent-install
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/integrations-agent-install
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test -v ./tests/integrations-agent-install/...
```