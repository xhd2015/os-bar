# Scenario

**Feature**: dedup bump with new timestamp re-triggers notification

```
# same dir, timestamp changes (dedup bump), consumed resets
previous: [{/proj/a, T1, consumed:true}] + current: [{/proj/a, T2, consumed:false}] -> notify /proj/a
```

## Steps

1. Load dedup-bump fixtures.
2. Call `notification_diff` with `is_baseline=false`.

## Context

- Confirmed decision: re-notification on dedup bump is required.

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