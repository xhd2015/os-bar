## Expected

- `resp.HTTPStatus == 200`.
- `len(resp.Events) == 0` (8-day-old event pruned).
- Seeded `/stale-project` dir not present in list.

## Side Effects

- `events.json` rewritten without stale entries after daemon load.

## Errors

- Any events remaining after prune fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200, got %d", resp.HTTPStatus)
	}
	if len(resp.Events) != 0 {
		t.Fatalf("expected 0 events after prune-on-load, got %d: %+v", len(resp.Events), resp.Events)
	}
	for _, ev := range resp.Events {
		if ev.Dir == "/stale-project" {
			t.Fatal("stale event should have been pruned on load")
		}
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Log("store-rules/prune-on-load OK")
}
```