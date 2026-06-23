# Scenario

**Feature**: startup baseline seeds snapshot without notifying pre-existing events

```
# first poll after launch with is_baseline=true
previous: [] + current has stale unconsumed events -> notify_dirs: []
```

## Steps

1. Load `testdata/current.json` as current snapshot; previous is empty.
2. Call `notification_diff` with `is_baseline=true`.

## Context

- Confirmed decision: no notification burst for pre-existing unconsumed events on launch.

```go
func Setup(t *testing.T, req *Request) error {
	current, err := readFixtureFile("testdata/current.json")
	if err != nil {
		return err
	}
	req.PreviousJSON = "[]"
	req.CurrentJSON = current
	req.IsBaseline = true
	return nil
}
```