# Scenario

**Feature**: server package owns HTTP server and session store; tests drive it via thin CLI subprocess

```
# test harness builds agent-sessions CLI, serve delegates to server package
doctest Run(req) -> build CLI -> serve --state-dir --port -> server -> daemon

# HTTP client exercises REST API
doctest -> POST /api/notify -> daemon -> events.json + notify-logs.json
doctest <- GET /api/list (session events)
doctest <- GET /api/health | /api/integrations | /api/logs
```

## Preconditions

- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "cmd", "agent-sessions")`.
- The `serve` subcommand binds `127.0.0.1` only and accepts `--port` and `--state-dir`.
- **Isolation (mandatory):** Every test uses `stateDir` under `t.TempDir()` and never reads/writes real `~/.os-bar/`.
- Tests use ephemeral ports (`--port 0` or assigned high port); never bind production port `38271`.
- `AGENT_SESSIONS_STATE_DIR` overrides default state location for the daemon process.
- Integrations tests set `HOME` to a dedicated `fakeHome` temp dir.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Build `agent-sessions` binary to a temp path (once per test).
2. Create `stateDir := filepath.Join(t.TempDir(), "state")` when `req.StateDir` is empty.
3. Create `fakeHome` when integrations tests need isolated `HOME`.
4. If `req.SeedEvents` is set, copy fixture JSON into `stateDir/events.json` before daemon start.
5. Register `t.Cleanup` to stop the daemon subprocess.
6. Dispatch by `req.Action`:
   - `start_daemon` — build & start `serve`, store `BaseURL` in response
   - `stop_daemon` — stop background `serve`
   - `http_request` — ensure daemon running, perform one HTTP call
   - `http_sequence` — ensure daemon running, perform `req.HTTPSteps` in order
   - `daemon_singleton` — start twice, assert second exits 0
   - `integrations_install` — `POST /api/integrations/install` then refresh integrations list
7. Parse JSON bodies into `Response.Events`, `Response.Integrations`, `Response.LogEntries` where applicable.
8. Return `(*Response, nil)`.

## Context

- `SessionEvent` mirrors Swift `SessionEvent`: `{id, dir, timestamp, consumed}`.
- Store rules (parity with `SessionStore.swift`): dedup by dir, cap 20, prune >7 days on load, newest-first sort.
- Notify with `source=="notify"` adds a session event; otherwise log-only.
- Integrations status enum: `missing` | `installed` | `up_to_date` | `outdated`.
- Error parity: invalid JSON → 400, missing dir → 400, unknown path → 404, wrong method → 405.
