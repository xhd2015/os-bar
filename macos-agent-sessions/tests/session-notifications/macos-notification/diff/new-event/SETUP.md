# Scenario

**Feature**: brand-new unconsumed dir triggers notification

```
# empty previous, one new (dir, timestamp) in current
previous: [] + current: [{/proj/a, T1}] -> notify_dirs: ["/proj/a"]
```

## Steps

1. Load `testdata/previous.json` and `testdata/current.json`.
2. Call `notification_diff` with `is_baseline=false`.

## Context

- Represents first arrival of a session event after baseline was already established.

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