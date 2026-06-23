# Scenario

**Feature**: append-only JSONL writes on log-only notify

```
# first notify creates notify-logs.jsonl with one line
harness -> POST /api/notify (log-only) -> daemon -> notify-logs.jsonl (1 line + \n)

# second notify appends another line (no array rewrite)
harness -> POST /api/notify (log-only) x2 -> notify-logs.jsonl (2 lines)
```

## Preconditions

- Daemon writes to `notify-logs.jsonl`, not `notify-logs.json`.
- Each append adds exactly one newline-terminated JSON object line.

## Steps

1. Set `req.Action = http_sequence`.
2. Leaf `Setup` configures one or two log-only POST steps.
3. Assert on-disk `notify-logs.jsonl` line count and format.

## Context

- Uses `O_APPEND|O_CREATE|O_WRONLY` semantics (not full-file JSON marshal).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	return nil
}
```