## Expected

- `len(resp.Events) == 1`.
- `resp.Events[0].Dir == "/Users/xhd2015/Projects/xhd2015/os-bar"`.
- `resp.Events[0].Consumed == false`.

## Side Effects

- `events.json` contains one row for the project, not two basename duplicates.

## Errors

- Two events means path normalization missing in daemon `addEvent` dedup.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("dedup failed: expected count=1 for trailing-slash variants, got %d dirs=%v",
			len(resp.Events), eventDirs(resp.Events))
	}
	wantDir := "/Users/xhd2015/Projects/xhd2015/os-bar"
	if resp.Events[0].Dir != wantDir {
		t.Fatalf("expected canonical dir=%q, got %q", wantDir, resp.Events[0].Dir)
	}
	if resp.Events[0].Consumed {
		t.Fatal("expected consumed=false after dedup bump")
	}
	t.Logf("store-rules/dedup-trailing-slash OK: dir=%s", resp.Events[0].Dir)
}

func eventDirs(events []SessionEvent) []string {
	out := make([]string, len(events))
	for i, ev := range events {
		out[i] = ev.Dir
	}
	return out
}
```