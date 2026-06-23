# Scenario

**Feature**: multiple new dirs in one poll each trigger notification

```
# previous has one stable event; current adds two new (dir, timestamp) pairs
previous: [{/proj/existing, T0}] + current adds /proj/b, /proj/c -> notify both new dirs
```

## Steps

1. Load `testdata/previous.json` and `testdata/current.json`.
2. Call `notification_diff` with `is_baseline=false`.

## Context

- Unchanged `/proj/existing` must not appear in `notify_dirs`.

```go
func Setup(t *testing.T, req *Request) error {
	previous, err := readFixtureFile("testdata/previous.json")
	if err != nil {
		return err
	}
	current, err := readFixtureFile("testdata/current.json")
	if err != nil {
		return err
	}
	req.PreviousJSON = previous
	req.CurrentJSON = current
	req.IsBaseline = false
	return nil
}
```