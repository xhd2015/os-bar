# Agent-Sessions Install — Doc-Style Test Tree

Test suite for the `agent-sessions install` subcommand. Validates hook/script
installation for grok, codex, opencode, and pi; codex merge semantics; dry-run
behavior; idempotency; CLI validation; and hook-script fallback chain content.

All tests run in isolated temporary `HOME` and workspace directories — never
the real user home.

## Decision Tree

```
hook-installation/                         ROOT: Request{Action, Target, Global, ...}
│                                                   Response{ExitCode, Files, FakeHome, WorkDir, ...}
│                                                   Run() builds CLI, sets fake HOME, snapshots files
│
├── validation/                            DECISION: CLI flag validation
│   └── [SETUP] req.Action = "install", no Target flag
│   │
│   └── no-target-flag/                    LEAF: install without --pi/--grok/--codex/--opencode
│       ├── SETUP → Target="", no flags
│       ├── ASSERT → exit 1, stderr requires flag, no files under fakeHome/workDir
│
├── grok/                                  DECISION: Target = "grok"
│   └── [SETUP] req.Target = "grok"
│   │
│   ├── local-install/                     LEAF: --grok local
│   │   ├── SETUP → Global=false
│   │   ├── ASSERT → 2 files under workDir, JSON has Stop hook, script 0755
│   │
│   ├── global-install/                    LEAF: --grok --global
│   │   ├── SETUP → Global=true
│   │   ├── ASSERT → files under fakeHome only, not workDir
│   │
│   ├── idempotent/                        LEAF: --grok twice
│   │   ├── SETUP → RunTwice=true
│   │   ├── ASSERT → StdoutSecond has "up to date", file count unchanged
│   │
│   └── dry-run/                           LEAF: --grok --dry-run
│       ├── SETUP → DryRun=true
│       ├── ASSERT → stdout reports install, no files created
│   │
│   └── coexistence/                       DECISION: foreign hook files in .grok/hooks/
│       └── [SETUP] pre-seed separate .json file before install
│       │
│       └── preserves-foreign-file/          LEAF: other-hooks.json unchanged
│           ├── SETUP → testdata/grok-foreign-hooks.json as other-hooks.json
│           ├── ASSERT → foreign file intact + our agent-sessions.json + script
│
├── codex/                                 DECISION: Target = "codex"
│   └── [SETUP] req.Target = "codex"
│   │
│   ├── empty-hooks/                       DECISION: fresh install (no pre-existing hooks.json)
│   │   └── [SETUP] PreExistingHooksJSON = ""
│   │   │
│   │   ├── local/                         LEAF: --codex local, empty hooks
│   │   │   ├── SETUP → Global=false
│   │   │   ├── ASSERT → hooks.json + script under workDir, our Stop entry only
│   │   │
│   │   ├── global/                        LEAF: --codex --global, empty hooks
│   │   │   ├── SETUP → Global=true
│   │   │   ├── ASSERT → files under fakeHome/.codex/
│   │   │
│   │   └── dry-run/                       LEAF: --codex --dry-run, empty hooks
│   │       ├── SETUP → DryRun=true
│   │       ├── ASSERT → stdout reports install, hooks.json MISSING
│   │
│   └── merge/                             DECISION: pre-seeded hooks.json
│       └── [SETUP] loads testdata fixtures into PreExistingHooksJSON
│       │
│       ├── preserves-foreign/             LEAF: foreign UserPromptSubmit + Stop preserved
│       │   ├── SETUP → testdata/codex-foreign-hooks.json
│       │   ├── ASSERT → 2 Stop groups, foreign + ours, UserPromptSubmit intact
│       │
│       ├── upsert-ours/                   LEAF: stale our entry updated, no duplicate
│       │   ├── SETUP → testdata/codex-old-agent-sessions.json
│       │   ├── ASSERT → exactly 1 our Stop, command path updated
│       │
│       ├── empty-hooks-object/            LEAF: {"hooks":{}} → our Stop added
│       │   ├── SETUP → testdata/codex-empty.json
│       │   ├── ASSERT → Stop entry added
│       │
│       └── malformed-preexisting/         LEAF: invalid JSON → error, no corruption
│           ├── SETUP → PreExistingHooksJSON = "{not json"
│           ├── ASSERT → stdout reports merge error, hooks.json unchanged
│
├── opencode/                              DECISION: Target = "opencode"
│   └── [SETUP] req.Target = "opencode"
│   │
│   ├── local-no-warning/                  LEAF: --opencode local
│   │   ├── SETUP → Global=false
│   │   ├── ASSERT → stdout lacks "/config add plugin"
│   │
│   └── global-install/                    LEAF: --opencode --global
│       ├── SETUP → Global=true
│       ├── ASSERT → plugin at fakeHome/.config/opencode/plugins/
│
├── pi/                                    DECISION: Target = "pi" (smoke)
│   └── [SETUP] req.Target = "pi"
│   │
│   └── local-install/                     LEAF: --pi local
│       ├── SETUP → Global=false
│       ├── ASSERT → workDir/.pi/extensions/agent-sessions-hook.ts exists
│
└── script-content/                        DECISION: hook script content verification
    └── [SETUP] req.Target = "grok" (installs stop script)
    │
    └── hook-script-fallback-chain/         LEAF: script has jq/python3/node/grep chain
        ├── SETUP → grok local install
        ├── ASSERT → script contains fallback markers
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `validation/no-target-flag/` | No target flag → exit 1, stderr error, no files |
| 2 | `grok/local-install/` | `--grok` writes hooks JSON + executable stop script under workDir |
| 3 | `grok/global-install/` | `--grok --global` writes under fakeHome only |
| 4 | `grok/idempotent/` | Second run prints "up to date", files unchanged |
| 5 | `grok/dry-run/` | `--grok --dry-run` reports install, creates no files |
| 6 | `grok/coexistence/preserves-foreign-file/` | Pre-seeded `other-hooks.json` unchanged; our files added |
| 7 | `codex/empty-hooks/local/` | Fresh local codex install creates hooks.json + script |
| 8 | `codex/empty-hooks/global/` | Fresh global codex install under fakeHome |
| 9 | `codex/empty-hooks/dry-run/` | Codex dry-run reports install, hooks.json not created |
| 10 | `codex/merge/preserves-foreign/` | Merge preserves foreign hooks, appends our Stop |
| 11 | `codex/merge/upsert-ours/` | Merge upserts our Stop entry, updates command path |
| 12 | `codex/merge/empty-hooks-object/` | Empty hooks object gets our Stop entry |
| 13 | `codex/merge/malformed-preexisting/` | Malformed pre-existing JSON → error, no write |
| 14 | `opencode/local-no-warning/` | Local opencode install has no `/config add plugin` hint |
| 15 | `opencode/global-install/` | Global opencode plugin under fakeHome |
| 16 | `pi/local-install/` | Local pi extension smoke test |
| 17 | `script-content/hook-script-fallback-chain/` | Stop script contains jq/python3/node/grep markers |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Missing required target flag | `no-target-flag` | ✓ |
| Grok local install | `grok/local-install` | ✓ |
| Grok global install (isolated HOME) | `grok/global-install` | ✓ |
| Grok idempotent re-run | `grok/idempotent` | ✓ |
| Grok dry-run | `grok/dry-run` | ✓ |
| Grok preserves foreign hook file | `grok/coexistence/preserves-foreign-file` | ✓ |
| Codex fresh local install | `codex/empty-hooks/local` | ✓ |
| Codex fresh global install | `codex/empty-hooks/global` | ✓ |
| Codex dry-run (no write) | `codex/empty-hooks/dry-run` | ✓ |
| Codex merge preserves foreign hooks | `codex/merge/preserves-foreign` | ✓ |
| Codex merge upserts our entry | `codex/merge/upsert-ours` | ✓ |
| Codex merge into empty hooks object | `codex/merge/empty-hooks-object` | ✓ |
| Codex merge malformed JSON handling | `codex/merge/malformed-preexisting` | ✓ |
| OpenCode local (no stale warning) | `opencode/local-no-warning` | ✓ |
| OpenCode global install | `opencode/global-install` | ✓ |
| Pi local smoke install | `pi/local-install` | ✓ |
| Hook script fallback chain | `script-content/hook-script-fallback-chain` | ✓ |

## How to Run

```sh
# Automated tests (Go doctest framework)
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/hook-installation

# Vet the test tree structure
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest vet ./tests/hook-installation

# Run with verbose output
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test -v ./tests/hook-installation/...
```