## Expected

- `len(resp.Events) == 3` (count preserved; no event lost or added).
- Every event has `Consumed == true`, including the previously-consumed `/a`.
- The three dirs `/a`, `/b`, `/c` are all present (order is newest-first, but set membership is what matters).

## Side Effects

- `events.json` persists `consumed: true` for all three events after the bulk call.
- Event count, ids, dirs, and timestamps are preserved — only `consumed` flips.

## Errors

- Any event with `consumed == false` after `/api/events/consume-all` fails the test.
- A count other than 3 fails the test (proves no event was lost or duplicated).

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 3 {
		t.Fatalf("expected 3 events (count preserved), got %d", len(resp.Events))
	}
	wantDirs := map[string]bool{"/a": true, "/b": true, "/c": true}
	gotDirs := map[string]bool{}
	for _, ev := range resp.Events {
		if !ev.Consumed {
			t.Fatalf("expected all events consumed, but %q is consumed=false", ev.Dir)
		}
		gotDirs[ev.Dir] = true
	}
	for d := range wantDirs {
		if !gotDirs[d] {
			t.Fatalf("expected event for dir %q in list, missing", d)
		}
	}
	t.Log("store-rules/consume-all-events OK")
}
```
