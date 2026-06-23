# Scenario

**Feature**: notify log store caps at 200 entries on disk

```
# 201 log-only notifies with distinct dirs
harness -> POST /api/notify (x201) -> daemon compacts JSONL

# disk: ≤200 lines, oldest /proj-00 evicted
```

## Preconditions

- Cap constant `maxNotifyLogs = 200` in `store.go`.
- Each notify uses a unique `dir` so all 201 entries are distinct.

## Steps

1. POST 201 log-only notifies (`/proj-00` … `/proj-200`).
2. Assert on-disk line count and absence of oldest dir.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	return nil
}
```