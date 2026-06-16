## Preconditions
- All tests in this subtree exercise the HTTP server component.
- The test helper starts an ephemeral HTTP server (on a random available port, not 38271) and sends an HTTP request to it.
- The server uses the same routing and validation logic as the production server.

## Steps
- This is a grouping node. Specific steps are defined in each leaf.

## Context
- Server actions: `"server_post"` sends a POST request; `"server_method"` sends a request with a specified method.
- `http_method` (default `"POST"`): the HTTP method to use.
- `http_path` (default `"/api/notify"`): the URL path to request.
- `http_body`: the raw request body.
- `content_type` (default `"application/json"`): the Content-Type header value.
- The response includes `http_status` (HTTP status code), `http_body` (response body), and `events` (store state after request).

```go
func Setup(t *testing.T, req *Request) error {
	// All server leaves operate on the HTTP server.
	// Each leaf sets its specific request parameters.
	t.Logf("server: preparing HTTP server test")
	return nil
}
```
