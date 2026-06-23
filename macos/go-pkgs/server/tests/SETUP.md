# Scenario

**Feature**: server package owns metrics HTTP daemon; tests drive it via `os-bar-daemon serve` subprocess

```
# test harness builds os-bar-daemon CLI, serve delegates to server package
doctest Run(req) -> build CLI -> serve --state-dir --port --mock-metrics -> server -> daemon

# HTTP client exercises metrics REST API
doctest <- GET /api/metrics (cpu_percent, mem_percent, swap_total_bytes, swap_used_bytes, disk_total_bytes, disk_used_bytes)
doctest -> POST /api/test/advance-tick -> mock provider advances tick
doctest <- GET /api/health | /api/info

# formatter helpers (no daemon)
doctest -> monitor.FormatBytes(bytes) -> "2GB" | "100MB" | "0B"
doctest -> monitor.FormatSwapDisplay(total, used) -> "89%(8GB/9GB)"
doctest -> monitor.FormatDiskBytesBinaryUsed/Total(bytes) -> "200.00GB" | "500GB"
doctest -> monitor.FormatDiskBytesDecimal(bytes) -> "536.87GB" | "214.75GB" | "0B"
doctest -> monitor.FormatDiskDisplay(total, used) -> "40% (200.00GB/500GB, 214.75GB/536.87GB on MacOS Settings)"
```

## Preconditions

- The `os-bar` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "cmd", "os-bar")`.
- Built binary is named `os-bar-daemon` (distinct from Swift `os-bar` app executable).
- The `serve` subcommand binds `127.0.0.1` only and accepts `--port`, `--state-dir`, and `--mock-metrics`.
- **Isolation (mandatory):** Every test uses `stateDir` under `t.TempDir()` and never reads/writes real `~/.os-bar/`.
- Tests use ephemeral ports (`--port 0` or assigned high port); never bind production port `38270`.
- `OS_BAR_STATE_DIR` overrides default state location for the daemon process.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Build `os-bar-daemon` binary to a temp path (once per test).
2. Create `stateDir := filepath.Join(t.TempDir(), "state")` when `req.StateDir` is empty.
3. Register `t.Cleanup` to stop the daemon subprocess.
4. Dispatch by `req.Action`:
   - `start_daemon` — build & start `serve`, store `BaseURL` in response
   - `stop_daemon` — stop background `serve`
   - `http_request` — ensure daemon running, perform one HTTP call
   - `http_sequence` — ensure daemon running, perform `req.HTTPSteps` in order
   - `daemon_singleton` — start twice, assert second exits 0
   - `metrics_fetch` — `GET /api/metrics`, parse into `CPUPercent` / `MEMPercent` / swap bytes
   - `metrics_tick` — `GET /api/metrics`, `POST /api/test/advance-tick`, `GET /api/metrics`; encode before/after CPU/MEM/swap in `HTTPBody`
   - `format_bytes` — call `monitor.FormatBytes(req.FormatBytesInput)`, store in `FormatResult`
   - `format_swap_display` — call `monitor.FormatSwapDisplay(req.FormatSwapTotal, req.FormatSwapUsed)`, store in `FormatResult`
   - `format_disk_bytes` — call `monitor.FormatDiskBytesDecimal(req.FormatBytesInput)`, store in `FormatResult`
   - `format_disk_bytes_binary_used` — call `monitor.FormatDiskBytesBinaryUsed(req.FormatBytesInput)`, store in `FormatResult`
   - `format_disk_bytes_binary_total` — call `monitor.FormatDiskBytesBinaryTotal(req.FormatBytesInput)`, store in `FormatResult`
   - `format_disk_display` — call `monitor.FormatDiskDisplay(req.FormatDiskTotal, req.FormatDiskUsed)`, store in `FormatResult`
5. Parse `/api/metrics` JSON into `Response.CPUPercent` / `Response.MEMPercent` / swap and disk byte fields.
6. Return `(*Response, nil)`.

## Context

- Metrics response: `{"cpu_percent": float64, "mem_percent": float64, "swap_total_bytes": uint64, "swap_used_bytes": uint64, "disk_total_bytes": uint64, "disk_used_bytes": uint64}`; CPU/MEM in `[0.0, 100.0]`.
- Mock tick 0: CPU=45.2, MEM=72.8, swap total=2147483648, swap used=104857600, disk total=536870912000, disk used=214748364800.
- Mock tick 1: CPU=52.3, MEM=68.1, swap total=2147483648, swap used=157286400, disk total=536870912000, disk used=241591910400.
- Mock tick 2+: CPU=38.7, MEM=75.4, swap total=4294967296, swap used=209715200, disk total=1099511627776, disk used=429496729600.
- `FormatBytes` / `FormatSwapDisplay`: binary (1024) units, integer labels only (`2GB`, `100MB`, `0B`).
- `FormatDiskBytesBinaryUsed` / `FormatDiskBytesBinaryTotal`: 1024-based labels (`200.00GB` used, `500GB` total).
- `FormatDiskBytesDecimal` / `FormatDiskDisplay`: decimal (1000) labels (`494.38GB`) plus dual-line display with `on MacOS Settings` suffix.
- `POST /api/test/advance-tick` returns 403 when not in mock mode.
- Error parity: unknown path → 404, wrong method on known path → 405.
- Singleton: second `serve` exits 0 if existing PID alive and `/api/health` OK.
