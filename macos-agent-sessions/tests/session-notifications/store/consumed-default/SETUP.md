## Steps
1. Call `Run(t, req)` with `action: "add_event"` and `dir: "/a"`.
2. Capture the `Response` with the event and `unconsumed_count`.

## Context
- New events default to `consumed = false`.
- The `unconsumed_count` reflects the number of events where `consumed == false`.
- After adding one event to an empty store, `unconsumed_count` should be 1.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "add_event"
	req.Dir = "/a"
	return nil
}
```
