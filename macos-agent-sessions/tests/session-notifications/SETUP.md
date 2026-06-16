## Preconditions
- The `macos-agent-sessions` Swift package exists with `SessionStore`, `SessionServer`, and `SessionEvent` types.
- `SessionStore` persists events to `UserDefaults` under key `"sessionEvents"` as a JSON-encoded array of `SessionEvent`.
- A Swift test helper executable is built at `macos-agent-sessions/.build/test-helper` that accepts a JSON `Request` on stdin (single line) and outputs a JSON `Response` on stdout.
- The test helper links against the app target and can create `SessionStore` instances, invoke store actions, and run an embedded HTTP server for server tests.

## Steps
1. Build the Swift test helper if not already built: `swiftc -o .build/test-helper os-bar-agent-sessionsTests/TestHelper.swift`
2. Serialize `req` (Go `Request` struct) to JSON.
3. Pipe the JSON into the test helper via stdin.
4. Read the test helper's stdout and parse it as a JSON `Response` struct.
5. Return `(*Response, nil)` on success, or `(nil, error)` on failure.

## Context
- Action `"add_event"` calls `SessionStore.addEvent(dir:)`, returns updated events list and count.
- Action `"add_events_batch"` calls `addEvent` for multiple dirs in order, returns final store state.
- Action `"prune"` calls the internal prune logic (prune events older than 7 days), returns pruned events and count.
- Action `"mark_consumed"` calls `SessionStore.markConsumed(dir:)`, returns updated events, count, and unconsumed_count.
- Action `"unconsumed_count"` loads events from `events_json` and returns the count of events where `consumed == false`.
- Action `"relative_time"` accepts `timestamp_iso` and `reference_iso` (optional; defaults to current time) and returns the formatted relative time string.
- Action `"server_post"` starts an ephemeral HTTP server, sends an HTTP request with specified method/path/body/headers, and returns the HTTP status, body, and the store's events.
- All timestamps in events are ISO8601 strings (`"2006-01-02T15:04:05Z"`).
- The test helper uses an ephemeral port for server tests (not 38271) to avoid conflicts.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

```go
import (
	"encoding/json"
	"fmt"
	"os/exec"
	"path/filepath"
	"testing"
)

// SessionEvent mirrors the Swift SessionEvent model.
type SessionEvent struct {
	ID        string `json:"id"`
	Dir       string `json:"dir"`
	Timestamp string `json:"timestamp"`
	Consumed  bool   `json:"consumed"`
}

// Request is passed as JSON to the Swift test helper via stdin.
type Request struct {
	Action        string   `json:"action"`
	Dir           string   `json:"dir,omitempty"`
	Dirs          []string `json:"dirs,omitempty"`
	EventsJSON    string   `json:"events_json,omitempty"`
	TimestampISO  string   `json:"timestamp_iso,omitempty"`
	ReferenceISO  string   `json:"reference_iso,omitempty"`
	HTTPMethod    string   `json:"http_method,omitempty"`
	HTTPPath      string   `json:"http_path,omitempty"`
	HTTPBody      string   `json:"http_body,omitempty"`
	ContentType   string   `json:"content_type,omitempty"`
}

// Response is parsed from the Swift test helper's stdout.
type Response struct {
	Events          []SessionEvent `json:"events"`
	Count           int            `json:"count"`
	UnconsumedCount int            `json:"unconsumed_count"`
	HTTPStatus      int            `json:"http_status"`
	HTTPBody        string         `json:"http_body"`
	RelativeTime    string         `json:"relative_time"`
	Error           string         `json:"error"`
}

func Run(t *testing.T, req *Request) (*Response, error) {
	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	helperPath := filepath.Join(projectRoot, ".build", "test-helper")

	// Build the helper if needed (idempotent)
	helperSrc := filepath.Join(projectRoot, "os-bar-agent-sessionsTests", "TestHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("failed to build test helper: %w\n%s", err, out)
	}

	// Serialize request to JSON
	reqJSON, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Run the test helper with the request on stdin
	cmd := exec.Command(helperPath)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to get stdin pipe: %w", err)
	}
	go func() {
		defer stdin.Close()
		stdin.Write(reqJSON)
		stdin.Write([]byte("\n"))
	}()

	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("test helper failed (exit code %v): %w\n%s",
			cmd.ProcessState.ExitCode(), err, out)
	}

	var resp Response
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("failed to parse test helper output: %w\noutput: %s", err, out)
	}

	return &resp, nil
}
```
