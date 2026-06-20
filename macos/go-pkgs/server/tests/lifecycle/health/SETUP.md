# Scenario

**Feature**: daemon health endpoint confirms server readiness

```
# daemon starts in mock mode, health returns ok
doctest -> serve --mock-metrics -> daemon
doctest <- GET /api/health -> {"ok":true}
```

## Steps

1. Start daemon via `http_request` flow (implicit start in `Run`).
2. `GET /api/health` on the running daemon.

## Context

- Health must return HTTP 200 before other API tests proceed.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPRequest
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/health"
	return nil
}
```