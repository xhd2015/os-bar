# Scenario

**Feature**: POST /api/notify without dir returns 400

```
# invalid notify body missing required dir
harness -> POST /api/notify {} -> daemon -> 400
```

## Steps

1. POST `/api/notify` with empty JSON object `{}`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPRequest
	req.HTTPMethod = "POST"
	req.HTTPPath = "/api/notify"
	req.HTTPBody = `{}`
	return nil
}
```