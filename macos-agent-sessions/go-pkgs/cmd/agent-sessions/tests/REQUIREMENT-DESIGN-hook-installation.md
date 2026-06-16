# REQUIREMENT-DESIGN: agent-sessions install hook installation doctests

## Context

Package: `github.com/xhd2015/os-bar/macos-agent-sessions/go-pkgs/cmd/agent-sessions`

The `agent-sessions install` subcommand installs integration scripts for coding agents:

| Flag | Global path | Local path |
|------|-------------|------------|
| `--pi` | `~/.pi/agent/extensions/agent-sessions-hook.ts` | `<cwd>/.pi/extensions/agent-sessions-hook.ts` |
| `--opencode` | `~/.config/opencode/plugins/agent-sessions.ts` | `<cwd>/.opencode/plugins/agent-sessions.ts` |
| `--grok` | `~/.grok/hooks/agent-sessions.json` + `~/.grok/hooks/bin/agent-sessions-stop.sh` | `<cwd>/.grok/hooks/...` |
| `--codex` | merges into `~/.codex/hooks.json` + `~/.codex/hooks/agent-sessions-stop.sh` | `<cwd>/.codex/hooks.json` + script |

Bundled scripts live in `scripts/` (embedded via `//go:embed`).

**Codex merge semantics (critical):** `mergeCodexHooks` must **merge**, not replace. Existing third-party hooks are preserved. Only entries with `statusMessage: "os-bar agent-sessions notify"` are upserted.

**OpenCode local:** No stale `/config add plugin` warning for local installs.

**Hook script:** `agent-sessions-stop.sh` uses jq → python3 → node → grep fallback chain.

## Target test directory

```
/Users/xhd2015/Projects/xhd2015/os-bar/macos-agent-sessions/go-pkgs/cmd/agent-sessions/tests/hook-installation/
```

Follow doc-style test layout per doctest spec. Reference existing suite at:
`macos-agent-sessions/tests/session-notifications/` for SETUP.md / ASSERT.md patterns.

## Isolation requirement (MANDATORY)

**Never touch the user's real home directory.**

`Run(t, req)` MUST:
1. Create `t.TempDir()` for workspace.
2. Set `HOME` to a **separate** temp dir via `t.Setenv("HOME", fakeHome)` — distinct from cwd unless global install needs both.
3. Set `cmd.Dir` to workspace cwd for local installs.
4. For `--global` installs, paths resolve under fake `HOME` only.
5. Document in root SETUP.md Preconditions that all tests run in isolated temp HOME+cwd.

Verify isolation in asserts: output file paths must be under temp dirs, never `/Users/<realuser>/`.

## Data models (test harness)

### Request (root SETUP.md — not redefined by descendants)

```go
type Request struct {
    Action               string // "install"
    Target               string // "grok" | "codex" | "pi" | "opencode"
    Global               bool
    DryRun               bool
    PreExistingHooksJSON string // write to hooks.json before install (codex merge tests)
    RunTwice             bool   // run install twice (idempotent tests)
}
```

### Response

```go
type Response struct {
    ExitCode         int
    Stdout           string
    Stderr           string
    Files            map[string]string // absolute path → content or "MISSING"
    ScriptExecutable map[string]bool   // path → is executable
    FakeHome         string
    WorkDir          string
    Error            string
}
```

### Run(t, req)

1. `fakeHome := filepath.Join(t.TempDir(), "home")` — `os.MkdirAll(fakeHome, 0755)`
2. `workDir := filepath.Join(t.TempDir(), "proj")` — `os.MkdirAll(workDir, 0755)`
3. `t.Setenv("HOME", fakeHome)` — **required for every test**
4. Build `agent-sessions`: `go build -o <tmp>/agent-sessions .` from `filepath.Join(DOCTEST_ROOT, "..")`
5. If `PreExistingHooksJSON` non-empty, write to correct hooks.json path (global vs local) before install
6. Run `<binary> install --<target> [--global] [--dry-run]` with `cmd.Env = os.Environ()` (HOME already overridden)
7. If `RunTwice`, run install a second time and capture second stdout
8. Snapshot files under fakeHome and workDir based on target/global
9. Return Response with FakeHome and WorkDir for asserts

`DOCTEST_ROOT` = directory of root `SETUP.md`.

## Test scenarios (leaves)

### Group: validation
1. **no-target-flag** — `install` with no flags → exit 1, stderr mentions required flag, no files under fake HOME or workDir

### Group: grok
2. **grok-local-install** — `--grok` → writes `workDir/.grok/hooks/agent-sessions.json` + `bin/agent-sessions-stop.sh` (0755), JSON has Stop hook
3. **grok-global-install** — `--grok --global` → writes under `fakeHome/.grok/hooks/`, NOT under real user home
4. **grok-idempotent** — `--grok` twice → second stdout contains "up to date", file count unchanged
5. **grok-dry-run** — `--grok --dry-run` → stdout reports install, no files created

### Group: codex — empty hook (fresh install)
6. **codex-empty-hooks-local** — no pre-existing hooks.json, `--codex` local → creates hooks.json with only our Stop entry + script
7. **codex-empty-hooks-global** — no pre-existing hooks.json, `--codex --global` → creates under `fakeHome/.codex/`
8. **codex-dry-run-empty** — `--codex --dry-run`, no existing hooks → reports install, hooks.json NOT created

### Group: codex — hook merge
9. **codex-merge-preserves-foreign** — pre-seed hooks.json with `UserPromptSubmit` + foreign `Stop` (statusMessage "skynet stop") → after install: both preserved, our Stop appended (2 Stop groups total)
10. **codex-merge-upsert-ours** — pre-seed with old agent-sessions Stop entry (wrong command path) → after install: exactly 1 our entry, command path updated, no duplicate
11. **codex-merge-empty-hooks-object** — pre-seed `{"hooks":{}}` → after install: our Stop entry added
12. **codex-merge-malformed-preexisting** — pre-seed invalid JSON → install reports error, does not corrupt (optional if CLI handles gracefully)

### Group: opencode
13. **opencode-local-no-warning** — `--opencode` local → stdout does NOT contain `/config add plugin`
14. **opencode-global-install** — `--opencode --global` → plugin at `fakeHome/.config/opencode/plugins/agent-sessions.ts`

### Group: pi (smoke)
15. **pi-local-install** — `--pi` → `workDir/.pi/extensions/agent-sessions-hook.ts`

### Group: script content
16. **hook-script-fallback-chain** — after grok install, script contains jq, python3, node, grep markers

## testdata/ fixtures

```
testdata/
├── codex-empty.json              → {"hooks":{}}
├── codex-foreign-hooks.json      → UserPromptSubmit + foreign Stop
├── codex-old-agent-sessions.json → our statusMessage with stale command path
```

## Expected outputs (summary)

| Leaf | Exit | Key side effects |
|------|------|------------------|
| no-target-flag | 1 | no files |
| grok-local-install | 0 | 2 files under workDir |
| grok-global-install | 0 | files under fakeHome only |
| grok-idempotent | 0 | "up to date" on 2nd run |
| grok-dry-run | 0 | no files |
| codex-empty-hooks-local | 0 | fresh hooks.json + script |
| codex-empty-hooks-global | 0 | under fakeHome |
| codex-dry-run-empty | 0 | no hooks.json |
| codex-merge-preserves-foreign | 0 | 3 hook events preserved + ours |
| codex-merge-upsert-ours | 0 | 1 our Stop, path updated |
| codex-merge-empty-hooks-object | 0 | Stop added to empty hooks |
| opencode-local-no-warning | 0 | no `/config add` in stdout |
| opencode-global-install | 0 | plugin under fakeHome |
| pi-local-install | 0 | pi extension exists |
| hook-script-fallback-chain | 0 | script has fallback markers |

## How to run

```sh
cd /Users/xhd2015/Projects/xhd2015/os-bar/macos-agent-sessions/go-pkgs/cmd/agent-sessions
doctest test ./tests/hook-installation
doctest vet ./tests/hook-installation
```

## Notes for designer

- Write full DOCTEST.md with decision tree diagram and test index.
- Root SETUP.md owns Request, Response, Run — descendants only add Setup() steps.
- **Every test must use isolated temp HOME** — assert paths stay under FakeHome/WorkDir.
- Group codex tests under `codex/empty-hooks/` and `codex/merge/` decision nodes.
- Do NOT modify production `.go` source files — tests only.
- Package dir for build: `filepath.Join(DOCTEST_ROOT, "..")`.