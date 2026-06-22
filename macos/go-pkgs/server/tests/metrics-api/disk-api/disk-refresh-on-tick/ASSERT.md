## Expected

- Before (tick 0): `disk_total=536870912000`, `disk_used=214748364800`.
- After (tick 1): `disk_total=536870912000`, `disk_used=241591910400`.
- Disk used changes; disk total unchanged between tick 0 and tick 1.

## Side Effects

- Mock provider internal tick counter advances by one.

## Errors

- Unchanged disk used after advance-tick fails the test.
- Total changing between tick 0 and tick 1 fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from final /api/metrics, got %d", resp.HTTPStatus)
	}

	tick := parseMetricsTickResult(t, resp.HTTPBody)

	const wantTotal = uint64(536870912000)
	const wantUsedBefore = uint64(214748364800)
	const wantUsedAfter = uint64(241591910400)

	if tick.BeforeDiskTotal != wantTotal {
		t.Fatalf("before_disk_total: got %d, want %d", tick.BeforeDiskTotal, wantTotal)
	}
	if tick.AfterDiskTotal != wantTotal {
		t.Fatalf("after_disk_total: got %d, want %d", tick.AfterDiskTotal, wantTotal)
	}
	if tick.BeforeDiskUsed != wantUsedBefore {
		t.Fatalf("before_disk_used: got %d, want %d", tick.BeforeDiskUsed, wantUsedBefore)
	}
	if tick.AfterDiskUsed != wantUsedAfter {
		t.Fatalf("after_disk_used: got %d, want %d", tick.AfterDiskUsed, wantUsedAfter)
	}
	if tick.BeforeDiskUsed == tick.AfterDiskUsed {
		t.Fatal("expected disk_used_bytes to change after advance-tick")
	}
	if tick.BeforeDiskTotal != tick.AfterDiskTotal {
		t.Fatalf("expected disk_total_bytes to stay constant: before=%d after=%d",
			tick.BeforeDiskTotal, tick.AfterDiskTotal)
	}
	if tick.AfterDiskUsed > tick.AfterDiskTotal {
		t.Fatalf("after tick: disk_used (%d) > disk_total (%d)", tick.AfterDiskUsed, tick.AfterDiskTotal)
	}

	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("disk-refresh-on-tick OK: used %d→%d, total=%d",
		tick.BeforeDiskUsed, tick.AfterDiskUsed, tick.AfterDiskTotal)
}
```