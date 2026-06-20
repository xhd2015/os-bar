## Expected

- `len(resp.Events) == 1`.
- `resp.Events[0].Dir == "/d"`.
- `resp.Events[0].Consumed == false`.
- Event timestamp is valid ISO8601 and recent (within last minute).

## Side Effects

- Only one event row for `/d` in `events.json`.

## Errors

- `len(resp.Events) != 1` fails (duplicate not deduped).
- `consumed == true` fails (dedup must reset consumed).

```go
import "time"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("dedup failed: expected count=1, got %d", len(resp.Events))
	}
	ev := resp.Events[0]
	if ev.Dir != "/d" {
		t.Fatalf("expected dir=/d, got %q", ev.Dir)
	}
	if ev.Consumed {
		t.Fatal("expected consumed=false after dedup bump")
	}
	ts, err := parseTimeISO(ev.Timestamp)
	if err != nil {
		t.Fatalf("invalid timestamp %q: %v", ev.Timestamp, err)
	}
	if time.Since(ts) > time.Minute {
		t.Fatalf("expected recent timestamp after dedup bump, got %s", ev.Timestamp)
	}
	t.Logf("store-rules/dedup-bump OK: ts=%s", ev.Timestamp)
}
```