# Scenario

**Feature**: identical poll snapshots produce no notifications

```
# previous equals current byte-for-byte
previous == current -> notify_dirs: []
```

## Steps

1. Load the same `snapshot.json` for both previous and current.
2. Call `notification_diff` with `is_baseline=false`.

```go
func Setup(t *testing.T, req *Request) error {
	snapshot, err := readFixtureFile("testdata/snapshot.json")
	if err != nil {
		return err
	}
	req.PreviousJSON = snapshot
	req.CurrentJSON = snapshot
	req.IsBaseline = false
	return nil
}
```