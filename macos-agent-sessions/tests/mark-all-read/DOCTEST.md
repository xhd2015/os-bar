# Mark All Read Menu Item — Doc-Style Test Tree

Test suite for the **“Mark All Read”** dropdown button state: its label
(constant `"Mark All Read"`) and its enabled flag (`unconsumedCount > 0`).
Pure-logic — no UI rendering — mirroring the `session-menu-item` pattern.
Uses the Swift `TestHelper` via a new `mark_all_read_state` action.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **menu bar dropdown** (`MenuBarDropdownContent`) shows session events and,
after the session list, a **“Mark All Read”** button. Clicking it calls
`SessionStore.markAllRead()` → `DaemonClient.consumeAll()` → refresh, clearing
the bell badge to 0.

The button has two observable, logic-derived properties:

- **Label** — the constant string `"Mark All Read"` (never changes).
- **Enabled** — `true` when at least one session event is unconsumed
  (`unconsumedCount > 0`), `false` otherwise (greyed out empty state).

`unconsumedCount` is derived from the loaded `SessionEvent` list: the number of
events whose `consumed == false`.

**TestMarkAllReadState** (new TestHelper formatter) mirrors this derivation:
given a preload of `SessionEvent`s, it returns `button_label`,
`button_enabled`, and `unconsumed_count`. **TestHelper** exposes the
`mark_all_read_state` action on stdin/stdout for the Go doctest harness.

## Decision Tree

```
mark-all-read/                             ROOT: Request{Action, EventsJSON, ...}
│                                                   Response{ButtonLabel, ButtonEnabled, UnconsumedCount, ...}
│                                                   Run() → Swift test helper
│
└── state/                                 DECISION: button enabled/label vs unconsumed count
    └── [SETUP] req.Action = mark_all_read_state
    │
    ├── disabled-when-none/                LEAF: 0 unconsumed → enabled=false, label="Mark All Read"
    └── enabled-when-some/                 LEAF: >0 unconsumed → enabled=true, label="Mark All Read"
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `state/disabled-when-none/` | All events consumed → `button_enabled=false`, `button_label="Mark All Read"` |
| 2 | `state/enabled-when-some/` | ≥1 unconsumed event → `button_enabled=true`, `button_label="Mark All Read"` |

## How to Run

```sh
cd macos-agent-sessions

doctest vet ./tests/mark-all-read
doctest test ./tests/mark-all-read
doctest test -v ./tests/mark-all-read/...
```

```go
import (
	"encoding/json"
	"fmt"
	"os/exec"
	"path/filepath"
	"testing"
)

const actionMarkAllReadState = "mark_all_read_state"

// Request drives Swift test-helper actions. Defined only at root.
type Request struct {
	Action     string `json:"action"`
	EventsJSON string `json:"events_json,omitempty"` // JSON array of SessionEvent
}

// Response captures mark-all-read button state.
type Response struct {
	Error           string `json:"error,omitempty"`
	ButtonLabel     string `json:"button_label,omitempty"`
	ButtonEnabled   bool   `json:"button_enabled"`
	UnconsumedCount int    `json:"unconsumed_count"`
}

func runSwiftTestHelper(t *testing.T, req *Request) (*Response, error) {
	t.Helper()
	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	helperPath := filepath.Join(projectRoot, ".build", "test-helper")
	helperSrc := filepath.Join(projectRoot, "os-bar-agent-sessionsTests", "TestHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("failed to build test helper: %w\n%s", err, out)
	}
	reqJSON, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}
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

func Run(t *testing.T, req *Request) (*Response, error) {
	switch req.Action {
	case actionMarkAllReadState:
		return runSwiftTestHelper(t, req)
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
