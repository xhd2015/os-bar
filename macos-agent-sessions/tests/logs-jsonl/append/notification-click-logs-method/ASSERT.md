## Expected

- One JSONL line on disk after POST.
- Parsed `command.openMethod == "kool_ipc"`.
- `command.koolAttempted == true` and `command.koolIpcHandled == true`.
- `GET /api/logs` (if queried) returns the same fields in the array entry.

## Errors

- Missing `openMethod` key means notification click logging contract not implemented in store.

```go
import (
	"encoding/json"
	"os"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	assertStateDirIsolated(t, resp.StateDir)

	lines := readJSONLLines(t, logsJSONLPath(resp.StateDir))
	if len(lines) != 1 {
		t.Fatalf("expected 1 JSONL line, got %d", len(lines))
	}
	var entry NotifyLogEntry
	if jsonErr := json.Unmarshal([]byte(lines[0]), &entry); jsonErr != nil {
		t.Fatalf("unmarshal: %v", jsonErr)
	}
	if entry.Command == nil {
		t.Fatal("expected command object on log entry")
	}
	cmd := entry.Command
	if cmd.OpenMethod != "kool_ipc" {
		t.Fatalf("openMethod=%q want kool_ipc", cmd.OpenMethod)
	}
	if !cmd.KoolAttempted || !cmd.KoolIpcHandled {
		t.Fatalf("koolAttempted=%v koolIpcHandled=%v", cmd.KoolAttempted, cmd.KoolIpcHandled)
	}
	if cmd.Command == "" {
		t.Fatal("command string must be persisted")
	}
	// Ensure fields survive API read when last step was GET /api/logs
	if len(resp.LogEntries) > 0 {
		last := resp.LogEntries[len(resp.LogEntries)-1]
		if last.Command == nil || last.Command.OpenMethod != "kool_ipc" {
			t.Fatalf("API log entry missing openMethod: %+v", last.Command)
		}
	}
	_, _ = os.Stat(logsJSONLPath(resp.StateDir))
}
```