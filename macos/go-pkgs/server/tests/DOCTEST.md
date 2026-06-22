# Server Package — Doc-Style Test Tree

Test suite for the `go-pkgs/server` library exercised via the thin
`os-bar-daemon serve` CLI. Validates process lifecycle (health, singleton)
and metrics HTTP API parity with the former Swift `SystemMonitor` /
`TestHelper` mock provider.

All tests run against an isolated state directory, ephemeral port, and
`--mock-metrics` — never production port `38270` or real `~/.os-bar/`.

# DSN (Domain Specific Notion)

The **server package** (`go-pkgs/server`) implements the daemon HTTP server
and metrics handlers. The thin **CLI** (`cmd/os-bar`, binary `os-bar-daemon`)
delegates `serve` to `server.RunServe`. The **daemon** is a long-lived
`os-bar-daemon serve` process bound to `127.0.0.1` on an ephemeral test
port (default production port `38270`).

A **metrics provider** (`go-pkgs/monitor`) supplies point-in-time CPU and MEM
percentages plus **swap stats** (`SwapTotal`, `SwapUsed` bytes from
`mem.VirtualMemory()` on macOS). In **mock mode** (`--mock-metrics`), the
provider returns deterministic tick-table values and exposes
`POST /api/test/advance-tick` to advance to the next snapshot (parity with
Swift `MockSystemInfoProvider`).

**CLI clients** (`os-bar metrics`) and **test harness HTTP clients** talk
to the daemon over JSON REST. A **metrics snapshot** is
`{cpu_percent, mem_percent, swap_total_bytes, swap_used_bytes}` — CPU/MEM
are `float64` in `[0.0, 100.0]`; swap fields are `uint64` with
`0 <= swap_used_bytes <= swap_total_bytes`.

A **format helper** (`monitor.FormatBytes`, `monitor.FormatSwapDisplay`)
converts raw byte counts to binary integer labels (`2GB`, `100MB`, `0B`) for
dropdown display; formatting is client-side in production but tested via the
shared Go helpers from the same harness.

On disk under the state dir (`$HOME/.os-bar/os-bar/`, overridable via
`--state-dir` or `OS_BAR_STATE_DIR`): `daemon.pid` only. No metrics history.

Mock tick table:

| Tick | CPU % | MEM % | swap_total_bytes | swap_used_bytes |
|------|-------|-------|------------------|-----------------|
| 0 | 45.2 | 72.8 | 2147483648 (2 GB) | 104857600 (100 MB) |
| 1 | 52.3 | 68.1 | 2147483648 (2 GB) | 157286400 (150 MB) |
| 2+ | 38.7 | 75.4 | 4294967296 (4 GB) | 209715200 (200 MB) |

## Decision Tree

```
server/tests/                                 ROOT: Request{Action, Port, StateDir, MockMetrics, ...}
│                                                      Response{BaseURL, HTTPStatus, CPUPercent, ...}
│                                                      Run() builds os-bar-daemon, starts serve, HTTP client
│
├── lifecycle/                                DECISION: concern = process lifecycle
│   └── [SETUP] ephemeral port, isolated state dir
│   │
│   ├── health/                               LEAF: GET /api/health → 200 ok
│   │   ├── SETUP → mock daemon, GET /api/health
│   │   └── ASSERT → status 200, body {"ok":true}
│   │
│   └── singleton/                            LEAF: second serve exits 0, one listener
│       ├── SETUP → Action=daemon_singleton
│       └── ASSERT → SecondStartExitCode=0, health OK, isolated PID file
│
└── metrics-api/                              DECISION: concern = metrics HTTP API (replaces menubar-monitor)
    └── [SETUP] MockMetrics=true, Action=metrics_fetch or metrics_tick
    │
    ├── cpu-in-range/                         LEAF: GET /api/metrics → cpu ∈ [0,100]
    ├── mem-in-range/                         LEAF: GET /api/metrics → mem ∈ [0,100]
    ├── both-valid/                           LEAF: both metrics present and in range
    ├── refresh-on-tick/                      LEAF: tick advances mock CPU/MEM (45.2→52.3)
    │
    ├── swap-api/                             DECISION: concern = swap HTTP API fields
    │   ├── swap-bytes-present/               LEAF: tick 0 swap fields present
    │   ├── swap-bytes-valid/                 LEAF: 0 <= used <= total
    │   └── swap-refresh-on-tick/             LEAF: tick 0→1 swap used changes, total stable
    │
    └── swap-format/                          DECISION: concern = swap display formatting
        ├── swap-format-total/                LEAF: FormatBytes(2 GiB) → "2GB"
        ├── swap-format-used/                 LEAF: FormatBytes(100 MiB) → "100MB"
        ├── swap-format-zero/                 LEAF: FormatBytes(0) → "0B"
        └── swap-format-display/              LEAF: FormatSwapDisplay → "2GB 100MB"
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Concern group | lifecycle, metrics-api |
| 2 | Swap concern | api (HTTP fields), format (FormatBytes helpers) |
| 3 | Action | metrics_fetch, metrics_tick, format_bytes, format_swap_display, ... |
| 4 | MockMetrics | true (API leaves), N/A (format leaves) |
| 5 | Tick state | 0 (present/valid/format), 0→1 (refresh) |
| 6 | Format input | total bytes, used bytes, zero, display pair |
| 7 | Port / StateDir | ephemeral port 0, isolated t.TempDir() state |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `lifecycle/health/` | `GET /api/health` returns 200 with `{"ok":true}` |
| 2 | `lifecycle/singleton/` | Second `serve` exits 0; one healthy listener remains |
| 3 | `metrics-api/cpu-in-range/` | `GET /api/metrics` → `cpu_percent ∈ [0.0, 100.0]` (mock tick 0: 45.2) |
| 4 | `metrics-api/mem-in-range/` | `GET /api/metrics` → `mem_percent ∈ [0.0, 100.0]` (mock tick 0: 72.8) |
| 5 | `metrics-api/both-valid/` | Both CPU and MEM in range and non-zero in mock mode |
| 6 | `metrics-api/refresh-on-tick/` | `POST /api/test/advance-tick` changes CPU/MEM (45.2→52.3 CPU) |
| 7 | `metrics-api/swap-api/swap-bytes-present/` | `GET /api/metrics` includes swap fields at mock tick 0 |
| 8 | `metrics-api/swap-api/swap-bytes-valid/` | `0 <= swap_used_bytes <= swap_total_bytes` |
| 9 | `metrics-api/swap-api/swap-refresh-on-tick/` | advance-tick: used 104857600→157286400, total stays 2147483648 |
| 10 | `metrics-api/swap-format/swap-format-total/` | `FormatBytes(2147483648)` → `"2GB"` |
| 11 | `metrics-api/swap-format/swap-format-used/` | `FormatBytes(104857600)` → `"100MB"` |
| 12 | `metrics-api/swap-format/swap-format-zero/` | `FormatBytes(0)` → `"0B"` |
| 13 | `metrics-api/swap-format/swap-format-display/` | `FormatSwapDisplay(2147483648, 104857600)` → `"2GB 100MB"` |

## How to Run

```sh
cd macos/go-pkgs/cmd/os-bar

# Validate tree structure
doctest vet ../../server/tests

# Run all server tests (RED until implementation lands)
doctest test ../../server/tests

# Run a single leaf
doctest test ../../server/tests/lifecycle/health

# Verbose
doctest test -v ../../server/tests/...
```