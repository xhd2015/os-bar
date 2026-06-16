## Preconditions
- The macOS project exists at `macos/os-bar.xcodeproj/` with the `os-bar` target.
- A `SystemMonitor` class is implemented in `macos/os-bar/SystemMonitor.swift`, exposed as `@Observable` with properties `cpuPercent: Double` and `memPercent: Double`.
- `SystemMonitor` accepts a configurable host-info fetcher so tests can inject mock data (no dependency on live OS metrics).
- A Swift test helper executable exists at `macos/.build/test-helper` that accepts a JSON `Request` on stdin (single line) and outputs a JSON `Response` on stdout. The helper creates a `SystemMonitor` instance with mock data, invokes the requested action, and prints the snapshot.

## Steps
1. Build the Swift test helper if not already built: `swiftc -o macos/.build/test-helper macos/os-barTests/TestHelper.swift`
2. Serialize `req` (Go `Request` struct) to JSON: `{"action": "<Action>"}`.
3. Pipe the JSON into the test helper via stdin.
4. Read the test helper's stdout and parse it as a JSON `Response` struct.
5. Return `(*Response, nil)` on success, or `(nil, error)` on failure.

## Context
- Action `"fetch"` means: take an immediate snapshot of CPU and MEM percentages.
- Action `"wait_tick"` means: wait for the next timer tick (or fast-forward the mock timer), then take a snapshot.
- The mock fetcher returns predetermined values: e.g., CPU = 45.2%, MEM = 72.8% on first fetch, and different values after each tick.
- Both `cpuPercent` and `memPercent` are `Double` values in the range `[0.0, 100.0]`.

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
