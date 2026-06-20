## Expected

- `len(resp.Events) == 20`.
- No event has `dir == "/proj-00"` (oldest of 21 evicted).
- Some event has `dir == "/proj-20"` (newest retained).

## Side Effects

- `events.json` contains exactly 20 entries.

## Errors

- `len != 20` fails the test.
- Presence of `/proj-00` fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 20 {
		t.Fatalf("expected cap 20 events, got %d", len(resp.Events))
	}
	hasOldest := false
	hasNewest := false
	for _, ev := range resp.Events {
		if ev.Dir == "/proj-00" {
			hasOldest = true
		}
		if ev.Dir == "/proj-20" {
			hasNewest = true
		}
	}
	if hasOldest {
		t.Fatal("expected /proj-00 evicted (oldest of 21)")
	}
	if !hasNewest {
		t.Fatal("expected /proj-20 retained (newest)")
	}
	t.Log("store-rules/cap-20 OK")
}
```