# Scenario

**Bug**: daemon treats trailing-slash dir as a separate session event

```
# first notify without trailing slash
harness -> POST /api/notify {dir:/Users/xhd2015/Projects/xhd2015/os-bar, source:notify}

# second notify with trailing slash (same project)
harness -> POST /api/notify {dir:/Users/xhd2015/Projects/xhd2015/os-bar/, source:notify}

# should dedup to one event
harness <- GET /api/list -> count=1
```

## Steps

1. POST notify for dir without trailing slash.
2. POST notify for same dir with trailing slash.
3. GET `/api/list`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/Users/xhd2015/Projects/xhd2015/os-bar","source":"notify"}`,
		},
		{
			Method: "POST",
			Path:   "/api/notify",
			Body:   `{"dir":"/Users/xhd2015/Projects/xhd2015/os-bar/","source":"notify"}`,
		},
		{Method: "GET", Path: "/api/list"},
	}
	return nil
}
```