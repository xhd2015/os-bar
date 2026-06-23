# Scenario

**Bug**: trailing-slash variant creates duplicate basename in menu

```
# same project dir with and without trailing slash
add_events_batch([
  "/Users/xhd2015/Projects/xhd2015/os-bar",
  "/Users/xhd2015/Projects/xhd2015/os-bar/"
])

# should dedup to one event (same canonical dir)
SessionStore -> count=1
```

## Steps

1. Call `add_events_batch` with the two path variants from the user report.
2. Assert store contains a single event for the canonical project dir.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "add_events_batch"
	req.Dirs = []string{
		"/Users/xhd2015/Projects/xhd2015/os-bar",
		"/Users/xhd2015/Projects/xhd2015/os-bar/",
	}
	return nil
}
```