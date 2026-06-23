# Scenario

**Feature**: session store, HTTP server, and macOS notification logic via Swift test helper

```
# doctest harness builds test helper, sends JSON Request on stdin
doctest Run(req) -> swiftc test-helper -> TestHelper.swift

# store actions exercise SessionStore rules
doctest -> add_event | prune | mark_consumed -> in-memory store -> events JSON

# server actions exercise embedded HTTP server
doctest -> POST /api/notify -> SessionServer -> events + http_status

# notification actions exercise SessionNotificationService logic (no real UNNotification)
doctest -> notification_diff | notification_content | notification_click -> notify_dirs, title/body/subtitle, opened_dir
```

## Preconditions

- The `macos-agent-sessions` Swift package exists with `SessionStore`, `SessionServer`, and `SessionEvent` types.
- `SessionStore` persists events to `UserDefaults` under key `"sessionEvents"` as a JSON-encoded array of `SessionEvent`.
- A Swift test helper executable is built at `macos-agent-sessions/.build/test-helper` that accepts a JSON `Request` on stdin (single line) and outputs a JSON `Response` on stdout.
- The test helper links against the app target and can create `SessionStore` instances, invoke store actions, and run an embedded HTTP server for server tests.
- Notification helper actions mirror `SessionNotificationService` diff/content/click logic without posting real notifications.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Build the Swift test helper if not already built: `swiftc -o .build/test-helper os-bar-agent-sessionsTests/TestHelper.swift`.
2. Serialize `req` (Go `Request` struct) to JSON.
3. Pipe the JSON into the test helper via stdin.
4. Read the test helper's stdout and parse it as a JSON `Response` struct.
5. Return `(*Response, nil)` on success, or `(nil, error)` on failure.

## Context

- Store actions: `"add_event"`, `"add_events_batch"`, `"prune"`, `"mark_consumed"`, `"unconsumed_count"`, `"relative_time"`.
- Server action: `"server_post"` — embedded HTTP server with ephemeral port (not 38271).
- Command-log actions: `"log_command_roundtrip"`, `"log_command_null_omit"`.
- Notification actions: `"notification_diff"`, `"notification_content"`, `"notification_click"`.
- All timestamps in events are ISO8601 strings (`"2006-01-02T15:04:05Z"`).
- `previous_json` / `current_json` are JSON arrays of `SessionEvent` for diff tests.
- `is_baseline=true` on first poll seeds baseline without notifying.

```go
import (
	"encoding/json"
	"fmt"
	"os"
	"testing"
)

// eventFixture builds JSON event arrays for notification diff tests.
type eventFixture struct {
	ID        string `json:"id"`
	Dir       string `json:"dir"`
	Timestamp string `json:"timestamp"`
	Consumed  bool   `json:"consumed"`
}

func buildEventsJSON(events []eventFixture) (string, error) {
	b, err := json.Marshal(events)
	if err != nil {
		return "", fmt.Errorf("marshal events: %w", err)
	}
	return string(b), nil
}

func readFixtureFile(name string) (string, error) {
	b, err := os.ReadFile(name)
	if err != nil {
		return "", fmt.Errorf("read fixture %s: %w", name, err)
	}
	return string(b), nil
}

func Setup(t *testing.T, req *Request) error {
	t.Logf("session-notifications: root setup — test helper will be built in Run")
	return nil
}
```