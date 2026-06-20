## Expected

- `resp.HTTPStatus == 200`.
- `resp.HTTPBody` contains `"ok":true` (JSON boolean true).
- `resp.BaseURL` is non-empty (`http://127.0.0.1:<port>`).
- `resp.Error == ""`.

## Side Effects

- `daemon.pid` written under isolated `resp.StateDir`.
- No reads or writes under real `~/.os-bar/`.

## Errors

- Non-200 health status fails the test.
- Missing `"ok":true` in body fails the test.

## Exit Code

- Daemon process remains running until test cleanup.

```go
import (
	"encoding/json"
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/health, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if !strings.Contains(resp.HTTPBody, `"ok":true`) {
		t.Fatalf("expected body to contain \"ok\":true, got %q", resp.HTTPBody)
	}
	var payload struct {
		OK bool `json:"ok"`
	}
	if err := json.Unmarshal([]byte(resp.HTTPBody), &payload); err != nil {
		t.Fatalf("parse health JSON: %v body=%q", err, resp.HTTPBody)
	}
	if !payload.OK {
		t.Fatalf("expected ok=true, got %v", payload.OK)
	}
	if resp.BaseURL == "" {
		t.Fatal("expected non-empty BaseURL")
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("lifecycle/health OK: baseURL=%s", resp.BaseURL)
}
```