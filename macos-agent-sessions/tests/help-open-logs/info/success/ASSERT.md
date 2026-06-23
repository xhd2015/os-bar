## Expected

- `resp.HTTPStatus == 200`.
- `resp.StoragePath` is non-empty and equals `resp.StateDir` (absolute paths normalized).
- `resp.HTTPBody` parses as JSON with `storage_path` matching the isolated state directory.
- `resp.Error == ""`.

## Side Effects

- `daemon.pid` written under isolated `resp.StateDir`.
- No reads or writes under real `~/.os-bar/`.

## Errors

- Non-200 status fails the test.
- Empty or mismatched `storage_path` fails the test.

## Exit Code

- Daemon process remains running until test cleanup.

```go
import (
	"encoding/json"
	"path/filepath"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/info, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.StoragePath == "" {
		t.Fatal("expected non-empty storage_path")
	}
	wantState, _ := filepath.Abs(resp.StateDir)
	gotPath, _ := filepath.Abs(resp.StoragePath)
	if gotPath != wantState {
		t.Fatalf("storage_path mismatch: got %q want %q", gotPath, wantState)
	}
	var payload struct {
		StoragePath string `json:"storage_path"`
		Port        int    `json:"port"`
		EventCount  int    `json:"event_count"`
	}
	if err := json.Unmarshal([]byte(resp.HTTPBody), &payload); err != nil {
		t.Fatalf("parse info JSON: %v body=%q", err, resp.HTTPBody)
	}
	if payload.StoragePath == "" {
		t.Fatal("JSON storage_path must be non-empty")
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("info/success OK: storage_path=%s", resp.StoragePath)
}
```