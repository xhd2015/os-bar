# Scenario

**Feature**: Config read/write behaviour — `GET /api/config` and `POST /api/config`

## Preconditions

- No `config.json` exists in state dir before the test begins (for default-missing).
- State dir is isolated `t.TempDir()` path.

## Steps

1. Set `req.Action = config_get` or `config_set`.
2. Root `Run()` builds binary, starts daemon, dispatches to handler.
3. `config_get`: `GET /api/config`, parse `open_method` from response.
4. `config_set`: `POST /api/config {open_method}`, then `GET /api/config` to verify.

## Context

- When `config.json` is missing, the daemon returns the default value `"vscode"`.
- Config persists immediately to `{stateDir}/config.json`.
- Invalid `open_method` values are rejected with HTTP 400.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("config: group setup — req.Action = %s", req.Action)
	return nil
}
```