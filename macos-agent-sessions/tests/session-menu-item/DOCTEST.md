# Session Menu Item Tooltip — Doc-Style Test Tree

Test suite for **session dropdown row formatting** in the menu bar app: visible
label (basename + relative time + consumed dot) and hover tooltip (full absolute
path). Uses the Swift `TestHelper` without UI automation.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **menu bar dropdown** (`MenuBarDropdownContent`) renders each `SessionEvent`
as a row: consumed indicator (`●` or spaces), basename padded to 22 chars, and
relative time (`5m ago`). The full project path lives on `event.dir` but is not
shown in the row text today.

**SessionMenuItemFormatter** (new) centralizes:
- `displayLabel(dir, consumed, relativeTime)` — row text for the dropdown
- `tooltip(dir)` — full absolute path for hover (`.help()` in SwiftUI)

**TestHelper** mirrors production formatter logic and exposes
`session_menu_item_state` on stdin/stdout for the Go doctest harness.

## Decision Tree

```
session-menu-item/                         ROOT: Request{Action, Dir, Consumed, ...}
│                                                   Response{DisplayLabel, MenuTooltip, ...}
│                                                   Run() → Swift test helper
│
├── tooltip/                               DECISION: concern = hover tooltip text
│   └── [SETUP] req.Action = session_menu_item_state
│   │
│   └── full-path/                         LEAF: tooltip equals input dir exactly
│
└── display/                               DECISION: concern = visible row label
    └── [SETUP] req.Action = session_menu_item_state
    │
    ├── basename-only/                     LEAF: label has basename, not full path
    ├── unconsumed-dot/                    LEAF: unconsumed → "● " prefix
    └── consumed-cleared/                  LEAF: consumed → "  " prefix (no bullet)
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `tooltip/full-path/` | `menu_tooltip` equals absolute `dir` |
| 2 | `display/basename-only/` | `display_label` contains basename only |
| 3 | `display/unconsumed-dot/` | unconsumed row starts with `● ` |
| 4 | `display/consumed-cleared/` | consumed row starts with two spaces |

## How to Run

```sh
cd macos-agent-sessions

doctest vet ./tests/session-menu-item
doctest test ./tests/session-menu-item
doctest test -v ./tests/session-menu-item/...
```

```go
import (
	"encoding/json"
	"fmt"
	"os/exec"
	"path/filepath"
	"testing"
)

const actionSessionMenuItemState = "session_menu_item_state"

// Request drives Swift test-helper actions. Defined only at root.
type Request struct {
	Action       string `json:"action"`
	Dir          string `json:"dir,omitempty"`
	Consumed     *bool  `json:"consumed,omitempty"`
	TimestampISO string `json:"timestamp_iso,omitempty"`
	ReferenceISO string `json:"reference_iso,omitempty"`
}

// Response captures formatter outcomes.
type Response struct {
	Error        string `json:"error,omitempty"`
	DisplayLabel string `json:"display_label,omitempty"`
	MenuTooltip  string `json:"menu_tooltip,omitempty"`
	RelativeTime string `json:"relative_time,omitempty"`
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
	case actionSessionMenuItemState:
		return runSwiftTestHelper(t, req)
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```