# Scenario

**Feature**: consumed flag change alone does not trigger notification

```
# same (dir, timestamp), only consumed flips true
previous: [{/proj/a, T1, consumed:false}] + current: [{/proj/a, T1, consumed:true}] -> notify_dirs: []
```

## Steps

1. Load consumed-only-change fixtures.
2. Call `notification_diff` with `is_baseline=false`.

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