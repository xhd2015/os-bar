# Scenario

**Feature**: Configurable directory open — daemon config API and open-dir dispatch

```
# config read/write: isolated serve + GET|POST /api/config
doctest Run(req) -> build agent-sessions -> serve --state-dir --port -> GET|POST /api/config

# open dir: isolated serve + POST /api/open-dir
doctest Run(req) -> build agent-sessions -> serve --state-dir --port -> POST /api/open-dir
```

## Preconditions

- The `agent-sessions` CLI exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")`.
- Config file stored at `{stateDir}/config.json` as `{"open_method":"vscode"|"iterm2"}`.
- When `config.json` is missing, `open_method` defaults to `"vscode"`.
- **Isolation (mandatory):** Every test uses `stateDir` under `t.TempDir()`; never reads/writes real `~/.os-bar/`.
- Tests use ephemeral ports; never bind production port `38271`.
- For vscode tests: `AGENT_SESSIONS_CODE_BINARY` env var points to a mock script.
- For iterm2 tests: `KOOL_ITERM2_INSTALLED=1` and `KOOL_ITERM2_SCRIPT_OUT` env vars are set.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Build `agent-sessions` binary from `go-pkgs/cmd/agent-sessions`.
2. Start `serve` with `--state-dir <tempDir>/state` and `--port <ephemeral>`.
3. Dispatch HTTP requests based on `req.Action`:
   - `config_get` — `GET /api/config`
   - `config_set` — `POST /api/config {open_method:"..."}` then `GET /api/config` to verify
   - `open_dir` — `POST /api/open-dir {dir, open_method}`
4. Leaf `Setup` configures action-specific parameters.
5. Leaf `Assert` validates HTTP status, response body fields.
6. Return `(*Response, nil)` on success.

## Context

- `open_method` in config can be `"vscode"` or `"iterm2"`. Invalid values rejected at write time.
- When `open_method` is omitted from `POST /api/open-dir`, the daemon falls back to the configured value.
- An explicit `open_method` in the request always overrides the config.
- The mock `code` binary records its directory argument to `stderr` for assertion.
- The iterm2 library writes the generated AppleScript to `KOOL_ITERM2_SCRIPT_OUT` path when set.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("dir-open: root setup — Run() dispatches by req.Action")
	return nil
}
```