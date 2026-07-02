# Scenario

**Feature**: Open dir dispatch behaviour — `POST /api/open-dir`

## Preconditions

- Daemon started with mock code binary via `AGENT_SESSIONS_CODE_BINARY`.
- For iterm2 tests: env vars `KOOL_ITERM2_INSTALLED=1` and `KOOL_ITERM2_SCRIPT_OUT=<path>` are set.
- State dir is isolated `t.TempDir()` path.

## Steps

1. Set `req.Action = open_dir`.
2. Configure `req.Dir` and `req.OpenMethod` via leaf SETUP.
3. Root `Run()` builds binary, starts daemon, dispatches POST /api/open-dir.
4. Assert response fields.

## Context

- `open_method` in request is optional; when omitted, daemon falls back to config value.
- Explicit `open_method` overrides config.
- The mock code binary echoes its args to stderr.
- The iterm2 library writes AppleScript to `KOOL_ITERM2_SCRIPT_OUT` when set.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("open-dir: group setup — req.Action = %s", req.Action)
	return nil
}
```