# Server Package — Doc-Style Test Tree

Test suite for the `go-pkgs/server` library exercised via the thin
`agent-sessions serve` CLI. Validates process lifecycle (health, singleton),
HTTP API parity with the former Swift server, session store rules (dedup, cap,
consume, prune-on-load), and integrations REST endpoints.

All tests run against an isolated state directory and ephemeral port — never
production port `38271` or real `~/.os-bar/`.

# DSN (Domain Specific Notion)

The **server package** (`go-pkgs/server`) implements the daemon HTTP server,
session store, and integrations handlers. The thin **CLI** (`cmd/agent-sessions`)
delegates `serve` to `server.RunServe`. The **daemon** is a long-lived
`agent-sessions serve` process bound to `127.0.0.1` on an ephemeral test port.
It owns session events, notify logs, and integration install status under a
configurable **state dir** (`AGENT_SESSIONS_STATE_DIR` or `--state-dir`).

**CLI clients** (`notify`, `list`, `remove`, …) and **test harness HTTP clients**
talk to the daemon over JSON REST. A **session event** is
`{id, dir, timestamp, consumed}` shown in the menu bar. A **notify** POST with
`source=="notify"` pushes into the session store; a **log-only notify** (any
other or absent `source`) appends to `notify-logs.json` only.

The **integrations API** exposes the same status JSON as
`integrations --json --global` and can run installs via HTTP. Tests use an
**isolated home** (`t.TempDir()` fake `HOME`) for integration install paths.

On disk under the state dir: `events.json`, `notify-logs.json`, `daemon.pid`.
`GET /api/info` returns `storage_path` pointing at that directory.

## Decision Tree

```
server/tests/                                 ROOT: Request{Action, Port, StateDir, ...}
│                                                      Response{BaseURL, HTTPStatus, Events, ...}
│                                                      Run() builds CLI, starts daemon, HTTP client
│
├── lifecycle/                                DECISION: concern = process lifecycle
│   └── [SETUP] daemon must be running or startable
│   │
│   ├── health/                               LEAF: GET /api/health → 200 ok
│   │   ├── SETUP → start daemon, GET /api/health
│   │   └── ASSERT → status 200, body contains "ok":true
│   │
│   └── singleton/                            LEAF: second serve exits 0, one listener
│       ├── SETUP → Action=daemon_singleton
│       └── ASSERT → SecondStartExitCode=0, health OK, same PID file
│
├── sessions-api/                             DECISION: concern = HTTP API parity
│   └── [SETUP] req.Action = http_sequence or http_request
│   │
│   ├── notify-adds-event/                  LEAF: source=notify → list has event
│   ├── notify-log-only/                    LEAF: no source=notify → logs yes, list no
│   ├── list-empty/                         LEAF: fresh daemon → empty list
│   ├── delete-events/                      LEAF: DELETE /api/events?dir=
│   ├── missing-dir/                        LEAF: POST {} → 400
│   ├── wrong-method/                       LEAF: GET /api/notify → 405
│   └── wrong-path/                         LEAF: POST /api/wrong → 404
│
├── store-rules/                              DECISION: concern = session store semantics
│   └── [SETUP] exercises store via HTTP after notify
│   │
│   ├── dedup-bump/                           LEAF: same dir twice → count 1, newer ts
│   ├── cap-20/                               LEAF: 21 dirs → list len 20
│   ├── consume-event/                        LEAF: POST /api/events/consume
│   └── prune-on-load/                        LEAF: seed 8-day-old event, restart, gone
│
└── integrations-api/                         DECISION: concern = integrations REST
    └── [SETUP] fake HOME, global scope
    │
    ├── list-all-missing/                     LEAF: GET /api/integrations?global=1
    └── install-grok/                         LEAF: POST install → up_to_date, files exist
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Concern group | lifecycle, sessions-api, store-rules, integrations-api |
| 2 | Action / HTTP path | health, notify, list, delete, consume, integrations |
| 3 | Request body / query | source=notify vs log-only, dir present vs missing |
| 4 | Store state | empty, seeded, multi-notify, stale events |
| 5 | HOME isolation | default temp vs fakeHome for integrations |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `lifecycle/health/` | `GET /api/health` returns 200 with `{"ok":true}` |
| 2 | `lifecycle/singleton/` | Second `serve` exits 0; one healthy listener remains |
| 3 | `sessions-api/notify-adds-event/` | `POST /api/notify` with `source=notify` adds session event |
| 4 | `sessions-api/notify-log-only/` | Notify without `source=notify` logs only, no menu event |
| 5 | `sessions-api/list-empty/` | Fresh daemon returns empty event list |
| 6 | `sessions-api/delete-events/` | `DELETE /api/events?dir=` removes matching events |
| 7 | `sessions-api/missing-dir/` | `POST /api/notify` without `dir` → 400 |
| 8 | `sessions-api/wrong-method/` | `GET /api/notify` → 405 |
| 9 | `sessions-api/wrong-path/` | `POST /api/wrong` → 404 |
| 10 | `store-rules/dedup-bump/` | Re-notify same dir bumps timestamp, count stays 1 |
| 11 | `store-rules/cap-20/` | 21 distinct dirs capped to 20 events |
| 12 | `store-rules/consume-event/` | `POST /api/events/consume` marks `consumed=true` |
| 13 | `store-rules/prune-on-load/` | 8-day-old seeded event pruned on daemon load |
| 14 | `integrations-api/list-all-missing/` | All four integrations report `missing` (global) |
| 15 | `integrations-api/install-grok/` | Install grok via API; status `up_to_date`, files exist |

## How to Run

```sh
cd macos-agent-sessions/go-pkgs/server

# Validate tree structure
doctest vet ./tests

# Run all server tests (GREEN after server package migration)
doctest test ./tests

# Run a single leaf
doctest test ./tests/lifecycle/health

# Verbose
doctest test -v ./tests/...
```