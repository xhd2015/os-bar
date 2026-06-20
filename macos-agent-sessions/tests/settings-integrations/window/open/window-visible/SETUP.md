## Steps
1. Run sequence: `open_settings` → `dump_layout`.
2. Capture `resp.WindowOpen` and `resp.Layout`.

## Context
- Empty `fakeHome`: all integrations missing in underlying state.
- Window should still show all four integration rows.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "sequence"
	req.Sequence = []Request{
		{Action: "open_settings"},
		{Action: "dump_layout"},
	}
	return nil
}
```