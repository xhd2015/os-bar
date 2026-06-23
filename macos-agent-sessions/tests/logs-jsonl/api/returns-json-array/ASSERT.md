## Expected

- `resp.HTTPStatus == 200`.
- `resp.HTTPBody` starts with `[` and ends with `]` (JSON array).
- Body does **not** contain newline-separated JSONL (no `}\n{` pattern from multi-line file).
- `len(resp.LogEntries) >= 1` with an entry for `/api-proj`.
- On disk: `notify-logs.jsonl` exists (JSONL), not legacy `.json`.

## Side Effects

- CLI `agent-sessions logs` and Swift `DaemonClient.listLogs()` keep array decode.

## Errors

- Non-array HTTP body or zero parsed entries fails the test.

```go
import (
	"encoding/json"
	"os"
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200, got %d", resp.HTTPStatus)
	}
	body := strings.TrimSpace(resp.HTTPBody)
	if !strings.HasPrefix(body, "[") || !strings.HasSuffix(body, "]") {
		t.Fatalf("GET /api/logs must return JSON array, got %q", body)
	}
	if strings.Contains(body, "}\n{") {
		t.Fatalf("response must not be JSONL text, got %q", body)
	}
	var arr []json.RawMessage
	if jsonErr := json.Unmarshal([]byte(body), &arr); jsonErr != nil {
		t.Fatalf("body must unmarshal as JSON array: %v", jsonErr)
	}
	if len(resp.LogEntries) < 1 {
		t.Fatalf("expected at least 1 log entry, got %d", len(resp.LogEntries))
	}
	found := false
	for _, e := range resp.LogEntries {
		if e.Dir == "/api-proj" {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected entry with dir=/api-proj, got %+v", resp.LogEntries)
	}
	if _, statErr := os.Stat(logsJSONLPath(resp.StateDir)); statErr != nil {
		t.Fatalf("expected notify-logs.jsonl on disk: %v", statErr)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("api/returns-json-array OK: array len=%d", len(arr))
}
```