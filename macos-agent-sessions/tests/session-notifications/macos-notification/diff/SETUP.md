# Scenario

**Feature**: dirsNeedingNotification diff detection after poll

```
# previous snapshot compared to current snapshot
previous events + current events -> dirsNeedingNotification -> notify_dirs[]

# baseline first poll seeds without notifying
is_baseline=true -> notify_dirs: []
```

## Preconditions

- Diff keys on `(dir, timestamp)` pair presence in previous snapshot.
- Identical snapshots and consumed-only changes produce empty `notify_dirs`.

## Steps

- Each leaf loads `previous.json` and `current.json` fixtures (or inline JSON) and sets `action: "notification_diff"`.

## Context

- `is_baseline` is only true for the startup baseline leaf.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_diff"
	return nil
}
```