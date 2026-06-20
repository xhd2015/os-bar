## Expected

- `len(resp.Events) == 1`.
- `resp.Events[0].Dir == "/consume-me"`.
- `resp.Events[0].Consumed == true`.

## Side Effects

- `events.json` persists `consumed: true` for `/consume-me`.

## Errors

- `consumed == false` after consume API fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(resp.Events))
	}
	ev := resp.Events[0]
	if ev.Dir != "/consume-me" {
		t.Fatalf("expected dir=/consume-me, got %q", ev.Dir)
	}
	if !ev.Consumed {
		t.Fatal("expected consumed=true after POST /api/events/consume")
	}
	t.Log("store-rules/consume-event OK")
}
```