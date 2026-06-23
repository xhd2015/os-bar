# Settings Integrations — Doc-Style Test Tree

Test suite for the **Integrations** settings window and `agent-sessions integrations --json`
detection command. Covers machine-readable install status (detection layer) and
accessibility layout capture with real click interactions (window layer).

Install/write logic is covered separately by `go-pkgs/cmd/agent-sessions/tests/hook-installation/`.
This suite focuses on status detection and UI presentation.


## Version

0.0.4

# DSN (Domain Specific Notion)

The **Integrations settings window** (SwiftUI) shows install status badges and Install
buttons for grok, opencode, pi, and codex. The **CLI** (`integrations --json`) exposes
the same status as machine-readable JSON. **Detection tests** drive the CLI with an
isolated `fakeHome`; **window tests** use a UI automation helper with Accessibility API.

Install/write logic is covered by `hook-installation/`; this suite focuses on status
detection and UI presentation only.

## Decision Tree

```
settings-integrations/                    ROOT: Request{Action, HomeDir, ...}, Response{Integrations, Layout, ...}
│                                                    Run() → CLI or UIAutomationHelper via stdin/stdout
│
├── detection/                            DECISION: layer = detection (no UI)
│   └── [SETUP] req.Action = integrations_json, req.Global = true
│   │
│   ├── all-missing/                      LEAF: empty fakeHome
│   │   ├── SETUP → SeedProfile = ""
│   │   └── ASSERT → 4 entries, all status missing, paths under fakeHome
│   │
│   ├── grok-installed/                   LEAF: bundled grok hooks seeded
│   │   ├── SETUP → SeedProfile = grok-installed
│   │   └── ASSERT → grok up_to_date, others missing
│   │
│   ├── pi-outdated/                      LEAF: pi file with wrong bytes
│   │   ├── SETUP → SeedProfile = pi-outdated
│   │   └── ASSERT → pi outdated, others missing
│   │
│   └── codex-merged/                     LEAF: foreign + our hooks merged
│       ├── SETUP → SeedProfile = codex-merged
│       └── ASSERT → codex up_to_date, foreign paths preserved in hooks.json
│
└── window/                               DECISION: layer = window (AX automation)
    └── [SETUP] req.Global = true; skip if kAXErrorAPIDisabled (-25211)
    │
    ├── open/                             DECISION: open Integrations window
    │   └── window-visible/               LEAF: -uiTestingOpenSettings entry
    │       ├── SETUP → sequence: open_settings → dump_layout
    │       └── ASSERT → window_open, integrations-window + 4 row ids
    │
    ├── layout/                           DECISION: badge + button layout
    │   └── all-missing-badges/           LEAF: empty HOME presentation
    │       ├── SETUP → sequence: open_settings → dump_layout
    │       └── ASSERT → each *-status Missing, each *-install AXButton
    │
    └── click-install/                    DECISION: install via UI click
        ├── grok-missing-to-installed/    LEAF: grok Install button
        │   ├── SETUP → sequence: open → dump → click grok-install → dump → teardown
        │   └── ASSERT → Missing→Up to date, hook files under fakeHome/.grok/
        │
        └── opencode-missing-to-installed/ LEAF: opencode Install button
            ├── SETUP → sequence: open → dump → click opencode-install → dump → teardown
            └── ASSERT → Missing→Up to date, plugin under fakeHome/.config/opencode/
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Layer | `detection` (CLI) vs `window` (AX UI) |
| 2 | Seed profile / HOME state | empty, grok-installed, pi-outdated, codex-merged |
| 3 | Window action | open, layout dump, click-install target |
| 4 | Scope | global only (v1) |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `detection/all-missing/` | Empty fakeHome → 4 integrations all `missing` |
| 2 | `detection/grok-installed/` | Seeded grok hooks → grok `up_to_date`, others `missing` |
| 3 | `detection/pi-outdated/` | Seeded wrong pi bytes → pi `outdated`, others `missing` |
| 4 | `detection/codex-merged/` | Merged hooks.json → codex `up_to_date`, foreign hooks preserved |
| 5 | `window/open/window-visible/` | `-uiTestingOpenSettings` opens window with 4 row identifiers |
| 6 | `window/layout/all-missing-badges/` | All status badges `Missing`, all install buttons present |
| 7 | `window/click-install/grok-missing-to-installed/` | Click grok Install → Up to date + files written |
| 8 | `window/click-install/opencode-missing-to-installed/` | Click opencode Install → Up to date + plugin written |

## Coverage Map

| Scenario | Leaf | Layer |
|----------|------|-------|
| All integrations missing (JSON) | `detection/all-missing` | detection |
| Grok up-to-date detection | `detection/grok-installed` | detection |
| Pi outdated detection | `detection/pi-outdated` | detection |
| Codex merge preservation | `detection/codex-merged` | detection |
| Window opens via test arg | `window/open/window-visible` | window |
| Missing badges + install buttons | `window/layout/all-missing-badges` | window |
| Grok install click transition | `window/click-install/grok-missing-to-installed` | window |
| OpenCode install click transition | `window/click-install/opencode-missing-to-installed` | window |

## Isolation

Every test creates `fakeHome` and `workDir` under `t.TempDir()`, sets `HOME=fakeHome`,
and never touches the real user home. Window helper receives the same dirs in `Request`.

## How to Run

```sh
# Vet test tree structure
cd /Users/xhd2015/Projects/xhd2015/os-bar/macos-agent-sessions
doctest vet ./tests/settings-integrations

# Run all tests (expected RED until implementation)
doctest test ./tests/settings-integrations

# Run detection only (no Accessibility required)
doctest test ./tests/settings-integrations/detection/...

# Run window only (requires Accessibility for test runner)
doctest test ./tests/settings-integrations/window/...

# Verbose
doctest test -v ./tests/settings-integrations/...
```

```go
import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const (
	actionIntegrationsJSON = "integrations_json"
	axErrorAPIDisabled     = "-25211"
	uiAutomationTimeout    = 30 * time.Second
)

// AXNode mirrors the accessibility layout tree from UIAutomationHelper.
type AXNode struct {
	Role       string   `json:"role"`
	Title      string   `json:"title,omitempty"`
	Identifier string   `json:"identifier,omitempty"`
	Value      string   `json:"value,omitempty"`
	Frame      *AXFrame `json:"frame,omitempty"`
	Children   []AXNode `json:"children,omitempty"`
}

type AXFrame struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
	W float64 `json:"w"`
	H float64 `json:"h"`
}

// Request drives detection CLI or UI automation helper. Defined only at root.
type Request struct {
	Action       string    `json:"action"`
	HomeDir      string    `json:"home_dir,omitempty"`
	WorkDir      string    `json:"work_dir,omitempty"`
	Identifier   string    `json:"identifier,omitempty"`
	Role         string    `json:"role,omitempty"`
	Title        string    `json:"title,omitempty"`
	Target       string    `json:"target,omitempty"`
	Global       bool      `json:"global,omitempty"`
	WaitMs       int       `json:"wait_ms,omitempty"`
	Sequence     []Request `json:"sequence,omitempty"`
	SeedProfile  string    `json:"seed_profile,omitempty"` // grok-installed | pi-outdated | codex-merged | ""
}

// Integration is one entry from integrations --json.
type Integration struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Path   string `json:"path"`
	Scope  string `json:"scope"`
}

// Response captures CLI or UI automation outcome.
type Response struct {
	Integrations []Integration `json:"integrations,omitempty"`
	Layout       *AXNode       `json:"layout,omitempty"`
	LayoutBefore *AXNode       `json:"layout_before,omitempty"`
	LayoutAfter  *AXNode       `json:"layout_after,omitempty"`
	WindowOpen   bool          `json:"window_open"`
	ClickX       float64       `json:"click_x,omitempty"`
	ClickY       float64       `json:"click_y,omitempty"`
	ClickOK      bool          `json:"click_ok"`
	HomeDir      string        `json:"home_dir"`
	WorkDir      string        `json:"work_dir"`
	Error        string        `json:"error,omitempty"`
}

func copyFile(src, dst string, perm os.FileMode) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("read %s: %w", src, err)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return fmt.Errorf("mkdir %s: %w", filepath.Dir(dst), err)
	}
	if err := os.WriteFile(dst, data, perm); err != nil {
		return fmt.Errorf("write %s: %w", dst, err)
	}
	return nil
}

func seedGrokInstalled(fakeHome string) error {
	testdata := filepath.Join(DOCTEST_ROOT, "testdata")
	hooksSrc := filepath.Join(testdata, "grok-hooks.json")
	scriptSrc := filepath.Join(testdata, "grok-stop.sh")

	hooksDst := filepath.Join(fakeHome, ".grok", "hooks", "agent-sessions.json")
	scriptDst := filepath.Join(fakeHome, ".grok", "hooks", "bin", "agent-sessions-stop.sh")

	if err := copyFile(hooksSrc, hooksDst, 0644); err != nil {
		return err
	}
	return copyFile(scriptSrc, scriptDst, 0755)
}

func seedPiOutdated(fakeHome string) error {
	src := filepath.Join(DOCTEST_ROOT, "testdata", "pi-outdated.ts")
	dst := filepath.Join(fakeHome, ".pi", "agent", "extensions", "agent-sessions-hook.ts")
	return copyFile(src, dst, 0644)
}

func seedCodexMerged(fakeHome string) error {
	scriptSrc := filepath.Join(DOCTEST_ROOT, "testdata", "grok-stop.sh")
	scriptDst := filepath.Join(fakeHome, ".codex", "hooks", "agent-sessions-stop.sh")
	if err := copyFile(scriptSrc, scriptDst, 0755); err != nil {
		return err
	}

	hooksSrc, err := os.ReadFile(filepath.Join(DOCTEST_ROOT, "testdata", "codex-merged-hooks.json"))
	if err != nil {
		return err
	}
	hooksText := strings.ReplaceAll(string(hooksSrc), "__CODEX_SCRIPT_PATH__", scriptDst)
	hooksDst := filepath.Join(fakeHome, ".codex", "hooks.json")
	if err := os.MkdirAll(filepath.Dir(hooksDst), 0755); err != nil {
		return err
	}
	return os.WriteFile(hooksDst, []byte(hooksText), 0644)
}

func applySeedProfile(profile, fakeHome string) error {
	switch profile {
	case "", "none":
		return nil
	case "grok-installed":
		return seedGrokInstalled(fakeHome)
	case "pi-outdated":
		return seedPiOutdated(fakeHome)
	case "codex-merged":
		return seedCodexMerged(fakeHome)
	default:
		return fmt.Errorf("unknown seed profile %q", profile)
	}
}

func buildCLIBinary(pkgDir, outPath string) error {
	buildCmd := exec.Command("go", "build", "-o", outPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return fmt.Errorf("go build agent-sessions: %w\n%s", err, out)
	}
	return nil
}

func buildUIHelper(projectRoot string) (string, error) {
	helperPath := filepath.Join(projectRoot, ".build", "ui-automation-helper")
	helperSrc := filepath.Join(projectRoot, "os-bar-agent-sessionsTests", "UIAutomationHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("failed to build ui-automation-helper: %w\n%s", err, out)
	}
	return helperPath, nil
}

func runIntegrationsJSON(t *testing.T, req *Request, cliBinary, fakeHome, workDir string) (*Response, error) {
	args := []string{"integrations", "--json"}
	if req.Global {
		args = append(args, "--global")
	}
	cmd := exec.Command(cliBinary, args...)
	cmd.Dir = workDir
	cmd.Env = os.Environ()
	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("integrations --json failed: %w\n%s", err, out)
	}

	var payload struct {
		Integrations []Integration `json:"integrations"`
	}
	if err := json.Unmarshal(out, &payload); err != nil {
		return nil, fmt.Errorf("parse integrations JSON: %w\noutput: %s", err, out)
	}

	return &Response{
		Integrations: payload.Integrations,
		HomeDir:      fakeHome,
		WorkDir:      workDir,
	}, nil
}

func uiAutomationTimeoutHints(helperPID int, stdout, stderr string) string {
	var b strings.Builder
	b.WriteString("ui-automation-helper did not finish within 30s — likely blocked waiting for child output or stdin EOF.\n")
	b.WriteString("\nCommon causes:\n")
	b.WriteString("  • Spawned app/daemon inherited the helper stdout/stderr pipe and never closed it → go test blocks on cmd.Wait() / json.Unmarshal(stdin)\n")
	b.WriteString("  • Stale os-bar-agent-sessions or agent-sessions serve processes from a prior killed run\n")
	b.WriteString("  • ui-automation.lock held by another parallel window test (serialized AX lock)\n")
	b.WriteString("  • Integrations window never became ready (daemon not healthy, refresh failed)\n")
	b.WriteString("\nDebug steps:\n")
	if helperPID > 0 {
		b.WriteString(fmt.Sprintf("  1. lsof -p %d | grep PIPE          # who holds pipe write ends?\n", helperPID))
		b.WriteString(fmt.Sprintf("  2. pgrep -lf 'ui-automation-helper|os-bar-agent-sessions|agent-sessions serve'\n"))
	} else {
		b.WriteString("  1. pgrep -lf 'ui-automation-helper|os-bar-agent-sessions|agent-sessions serve'\n")
	}
	b.WriteString("  3. Kill stale: pgrep -f 'os-bar-agent-sessions -uiTestingOpenSettings' | xargs kill -9; pgrep -f '.build/agent-sessions serve' | xargs kill -9\n")
	b.WriteString("  4. rm -f macos-agent-sessions/.build/ui-automation.lock\n")
	b.WriteString("  5. Re-run one leaf with -v: doctest test -v ./tests/settings-integrations/window/open/window-visible\n")
	b.WriteString("  6. Manual pipe test: printf '<json>' | .build/ui-automation-helper   (must return one JSON line, not hang)\n")
	b.WriteString("  7. Ensure UIAutomationHelper redirects app/daemon stdout+stderr to FileHandle.nullDevice\n")
	if trimmed := strings.TrimSpace(stderr); trimmed != "" {
		b.WriteString("\nHelper stderr (partial):\n")
		b.WriteString(trimmed)
		b.WriteString("\n")
	}
	if trimmed := strings.TrimSpace(stdout); trimmed != "" {
		b.WriteString("\nHelper stdout (partial):\n")
		b.WriteString(trimmed)
		b.WriteString("\n")
	}
	return b.String()
}

func runUIAutomation(t *testing.T, req *Request, projectRoot, fakeHome, workDir string) (*Response, error) {
	helperPath, err := buildUIHelper(projectRoot)
	if err != nil {
		return nil, err
	}

	req.HomeDir = fakeHome
	req.WorkDir = workDir
	reqJSON, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal UI request: %w", err)
	}

	cmd := exec.Command(helperPath)
	cmd.Env = os.Environ()
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("stdin pipe: %w", err)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start ui-automation-helper: %w", err)
	}
	helperPID := 0
	if cmd.Process != nil {
		helperPID = cmd.Process.Pid
	}
	_, _ = stdin.Write(reqJSON)
	_, _ = stdin.Write([]byte("\n"))
	stdin.Close()

	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	select {
	case err := <-done:
		if err != nil {
			combined := strings.TrimSpace(stdout.String() + "\n" + stderr.String())
			if strings.Contains(combined, axErrorAPIDisabled) {
				t.Skip("Accessibility API disabled (kAXErrorAPIDisabled); enable Accessibility for test runner")
			}
			return nil, fmt.Errorf("ui-automation-helper failed: %w\nstdout: %s\nstderr: %s", err, stdout.String(), stderr.String())
		}
	case <-time.After(uiAutomationTimeout):
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		<-done
		return nil, fmt.Errorf("%s", uiAutomationTimeoutHints(helperPID, stdout.String(), stderr.String()))
	}

	var resp Response
	if err := json.Unmarshal(stdout.Bytes(), &resp); err != nil {
		return nil, fmt.Errorf("parse ui-automation-helper output: %w\noutput: %s", err, stdout.String())
	}
	if resp.Error != "" {
		if strings.Contains(resp.Error, axErrorAPIDisabled) {
			t.Skip("Accessibility API disabled (kAXErrorAPIDisabled); enable Accessibility for test runner")
		}
		return &resp, fmt.Errorf("ui-automation-helper error: %s", resp.Error)
	}
	resp.HomeDir = fakeHome
	resp.WorkDir = workDir
	return &resp, nil
}

func findByIdentifier(node *AXNode, id string) *AXNode {
	if node == nil {
		return nil
	}
	stack := []*AXNode{node}
	for len(stack) > 0 {
		cur := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if cur.Identifier == id {
			return cur
		}
		for i := len(cur.Children) - 1; i >= 0; i-- {
			stack = append(stack, &cur.Children[i])
		}
	}
	return nil
}

func findByRoleTitle(node *AXNode, role, title string) *AXNode {
	if node == nil {
		return nil
	}
	stack := []*AXNode{node}
	for len(stack) > 0 {
		cur := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if cur.Role == role && cur.Title == title {
			return cur
		}
		for i := len(cur.Children) - 1; i >= 0; i-- {
			stack = append(stack, &cur.Children[i])
		}
	}
	return nil
}

func subtreeText(node *AXNode) string {
	if node == nil {
		return ""
	}
	var parts []string
	stack := []*AXNode{node}
	for len(stack) > 0 {
		cur := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if cur.Title != "" {
			parts = append(parts, cur.Title)
		}
		if cur.Value != "" {
			parts = append(parts, cur.Value)
		}
		for i := len(cur.Children) - 1; i >= 0; i-- {
			stack = append(stack, &cur.Children[i])
		}
	}
	return strings.Join(parts, " ")
}

func layoutContainsIdentifier(layout *AXNode, id string) bool {
	return findByIdentifier(layout, id) != nil
}

func integrationByID(integrations []Integration, id string) *Integration {
	for i := range integrations {
		if integrations[i].ID == id {
			return &integrations[i]
		}
	}
	return nil
}

func assertPathUnderHome(t *testing.T, path, fakeHome string) {
	t.Helper()
	absPath, err := filepath.Abs(path)
	if err != nil {
		t.Fatalf("abs %q: %v", path, err)
	}
	homeAbs, err := filepath.Abs(fakeHome)
	if err != nil {
		t.Fatalf("abs home %q: %v", fakeHome, err)
	}
	if !strings.HasPrefix(absPath, homeAbs+string(filepath.Separator)) && absPath != homeAbs {
		t.Fatalf("path %q is outside fakeHome %q", absPath, homeAbs)
	}
}

func Run(t *testing.T, req *Request) (*Response, error) {
	fakeHome := filepath.Join(t.TempDir(), "home")
	workDir := filepath.Join(t.TempDir(), "proj")
	if err := os.MkdirAll(fakeHome, 0755); err != nil {
		return nil, fmt.Errorf("mkdir fakeHome: %w", err)
	}
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return nil, fmt.Errorf("mkdir workDir: %w", err)
	}
	if req.HomeDir == "" {
		req.HomeDir = fakeHome
	}
	if req.WorkDir == "" {
		req.WorkDir = workDir
	}

	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	cliPkgDir := filepath.Join(projectRoot, "go-pkgs", "cmd", "agent-sessions")
	cliBinary := filepath.Join(t.TempDir(), "agent-sessions")
	if err := buildCLIBinary(cliPkgDir, cliBinary); err != nil {
		return nil, err
	}

	t.Setenv("HOME", fakeHome)

	if err := applySeedProfile(req.SeedProfile, fakeHome); err != nil {
		return nil, fmt.Errorf("seed profile %q: %w", req.SeedProfile, err)
	}

	switch req.Action {
	case actionIntegrationsJSON:
		return runIntegrationsJSON(t, req, cliBinary, fakeHome, workDir)
	case "open_settings", "dump_layout", "click", "sequence", "teardown":
		return runUIAutomation(t, req, projectRoot, fakeHome, workDir)
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
