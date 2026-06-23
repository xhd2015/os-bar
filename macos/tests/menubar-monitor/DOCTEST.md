# Menu Bar CPU/MEM Monitor — Doc-Style Test Tree

> **Deprecated (automated leaves):** Backend tests moved to `go-pkgs/server/tests/`.
> Run `cd go-pkgs/cmd/os-bar && doctest test ../../server/tests` instead.
> This tree is retained for manual UI verification (`ui/`).

Test suite for the `SystemMonitor` component of the macOS menu bar app.
Validates metric fetching, range correctness, timer-driven refresh behavior,
and (manually) menu bar rendering and quit functionality.
## Version

0.0.1

# DSN (Domain Specific Notion)

The **SystemMonitor** Swift component supplies CPU and memory percentages
for the menu bar. Tests drive it via a **Swift test helper**
(`macos/.build/test-helper`) that reads one JSON `Request` from stdin and
prints a JSON `Response` to stdout. A **mock fetcher** returns predetermined
tick values (no live OS metrics).

- Action `fetch`: immediate snapshot of `cpu_percent` and `mem_percent`.
- Action `wait_tick`: advance the mock timer, then snapshot.
- Both fields are `Double` in `[0.0, 100.0]`.


## Decision Tree

```
menubar-monitor/                          ROOT: Request{Action}, Response{CPUPercent, MEMPercent}
│                                                Run() wraps SystemMonitor via Swift test helper
│
├── metrics-range/                        DECISION: action = "fetch" (immediate snapshot)
│   └── [SETUP] req.Action = "fetch"
│   │
│   ├── cpu-in-range/                     LEAF: CPU metric in [0.0, 100.0]
│   │   ├── ASSERT → resp.CPUPercent ∈ [0, 100]
│   │
│   ├── mem-in-range/                     LEAF: MEM metric in [0.0, 100.0]
│   │   ├── ASSERT → resp.MEMPercent ∈ [0, 100]
│   │
│   └── both-valid/                       LEAF: both metrics present + in range
│       ├── ASSERT → cpu ∈ [0,100] AND mem ∈ [0,100]
│
├── refresh/                              DECISION: action = "wait_tick" (timer-driven refresh)
│   └── [SETUP] req.Action = "wait_tick"
│   │
│   └── updates-on-tick/                  LEAF: values change after timer tick
│       ├── SETUP → snapshot1 (fetch), snapshot2 (wait_tick)
│       ├── ASSERT → snap1 ≠ snap2, both still in valid range
│
└── ui/                                   MANUAL: visual verification (no automated assertions)
    ├── DOCTEST.md → menu bar rendering, quit, dark mode
    └── [SETUP] t.Skip() — manual only
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `metrics-range/cpu-in-range/` | CPU percentage is a Double in [0.0, 100.0] |
| 2 | `metrics-range/mem-in-range/` | MEM percentage is a Double in [0.0, 100.0] |
| 3 | `metrics-range/both-valid/` | Both CPU and MEM returned together and in valid range |
| 4 | `refresh/updates-on-tick/` | Timer fires, values refresh — snapshot2 differs from snapshot1 |
| M1 | `ui/` | Manual: menu bar renders icons + percentages |
| M2 | `ui/` | Manual: Quit menu item terminates the app |
| M3 | `ui/` | Manual: menu dropdown shows current metrics |
| M4 | `ui/` | Manual: Dark Mode compatibility |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| CPU metric fetched, valid range | `cpu-in-range` | ✓ |
| MEM metric fetched, valid range | `mem-in-range` | ✓ |
| Both metrics complete and valid | `both-valid` | ✓ |
| Timer fires, values refresh | `updates-on-tick` | ✓ |
| Menu bar renders | `ui/DOCTEST.md` Test 1 | Manual |
| Quit terminates app | `ui/DOCTEST.md` Test 2 | Manual |

## How to Run

```sh
# Automated tests (Go doctest framework)
cd macos && doctest test ./tests/menubar-monitor

# Swift unit tests (XCTest)
cd macos && xcodebuild test -scheme os-bar -destination 'platform=macOS'

# Manual UI verification
# Follow steps in tests/menubar-monitor/ui/DOCTEST.md
```

```go
import (
	"encoding/json"
	"fmt"
	"os/exec"
	"path/filepath"
	"testing"
)

type Request struct {
	Action string `json:"action"`
}

type Response struct {
	CPUPercent float64 `json:"cpu_percent"`
	MEMPercent float64 `json:"mem_percent"`
}

func Run(t *testing.T, req *Request) (*Response, error) {
	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	helperPath := filepath.Join(projectRoot, ".build", "test-helper")

	// Build the helper if needed (idempotent)
	helperSrc := filepath.Join(projectRoot, "os-barTests", "TestHelper.swift")
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
	cmd.Stdin = nil // will use pipe — see below
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
