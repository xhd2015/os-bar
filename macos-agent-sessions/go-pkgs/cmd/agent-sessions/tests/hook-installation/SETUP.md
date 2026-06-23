# Scenario

## Preconditions
- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..")` (parent of `tests/`).
- Bundled integration scripts are embedded via `//go:embed` in the production binary.
- **Isolation (mandatory):** Every test runs in isolated temporary directories. `Run` sets `HOME` to a dedicated `fakeHome` temp dir (never the real user home). Local installs use a separate `workDir` as `cmd.Dir`. Global installs resolve paths under `fakeHome` only.
- `os.UserHomeDir()` must resolve to `fakeHome` during each test because `HOME` is overridden via `t.Setenv`.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps
1. Create `fakeHome := filepath.Join(t.TempDir(), "home")` and `workDir := filepath.Join(t.TempDir(), "proj")`; `MkdirAll` both with mode `0755`.
2. Build the CLI **before** overriding `HOME` (avoids go telemetry writes into fakeHome).
3. `t.Setenv("HOME", fakeHome)` — required before running install; install `cmd.Env` inherits this override.
4. If `req.PreExistingHooksJSON` is non-empty, write it to the codex `hooks.json` path (global → `fakeHome/.codex/hooks.json`, local → `workDir/.codex/hooks.json`) before running install.
5. If `req.PreExistingGrokHooksJSON` is non-empty, write it to `<base>/.grok/hooks/<PreExistingGrokHookFile>` before running install.
6. Construct install args from `req` and run `<binary> install ...` with `cmd.Dir = workDir` and `cmd.Env = os.Environ()`.
7. If `req.RunTwice`, run install a second time; store second-run stdout in `StdoutSecond`.
8. Snapshot expected output paths under `fakeHome` and/or `workDir` into `Files` and `ScriptExecutable`.
9. Return `(*Response, nil)` with `FakeHome` and `WorkDir` populated for isolation asserts.

## Context
- `Action` is always `"install"` for this suite.
- `Target` is one of `"grok"`, `"codex"`, `"pi"`, `"opencode"`, or empty (validation only).
- Codex merge tests pre-seed `hooks.json` via `PreExistingHooksJSON` or load fixtures from `testdata/`.
- Grok coexistence tests pre-seed a separate hook file via `PreExistingGrokHookFile` + `PreExistingGrokHooksJSON`.
- Agent-sessions hook entries use `statusMessage: "os-bar agent-sessions notify"`.
- Codex `mergeCodexHooks` preserves foreign hooks; only our statusMessage entries are upserted.
- OpenCode local installs must not print the stale `/config add plugin` hint (that hint is global-only).
- `.sh` hook scripts are installed with mode `0755`.
