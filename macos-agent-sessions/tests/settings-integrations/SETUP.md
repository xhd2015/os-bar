## Preconditions
- The `macos-agent-sessions` Swift package exists with an Integrations settings window (title **Integrations**).
- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")`.
- A Swift UI automation helper is built at `macos-agent-sessions/.build/ui-automation-helper` from `os-bar-agent-sessionsTests/UIAutomationHelper.swift`.
- The app accepts launch argument `-uiTestingOpenSettings` to open the Integrations window directly.
- **Isolation (mandatory):** Every test runs in isolated temporary directories. `Run` sets `HOME` to a dedicated `fakeHome` temp dir (never the real user home). `workDir` is a separate fixture project directory. UI helper and CLI both receive the same `home_dir` / `work_dir`.
- **Accessibility (window tests only):** Window-layer tests require Accessibility permission for the test runner process. If the helper returns `kAXErrorAPIDisabled` (-25211), tests call `t.Skip` with a clear message. Detection tests do not require Accessibility.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps
1. Create `fakeHome := filepath.Join(t.TempDir(), "home")` and `workDir := filepath.Join(t.TempDir(), "proj")`; `MkdirAll` both with mode `0755`.
2. Populate `req.HomeDir` / `req.WorkDir` when empty.
3. Build binaries **before** overriding `HOME` (avoids go telemetry writes into fakeHome).
4. `t.Setenv("HOME", fakeHome)` — required before integration scan or app launch.
5. Apply `req.SeedProfile` fixtures under `fakeHome` only (see seed helpers below).
6. Route by `req.Action`:
   - `integrations_json` — run `agent-sessions integrations --json [--global]`, parse stdout
   - window actions — pipe JSON to `ui-automation-helper` via stdin, parse stdout
7. Return `(*Response, nil)` with `HomeDir` and `WorkDir` populated.

## Context
- Detection layer action: `integrations_json` — machine-readable install status for grok, opencode, pi, codex.
- Window layer actions: `open_settings`, `dump_layout`, `click`, `sequence`, `teardown`.
- `sequence` runs sub-requests in order; first `dump_layout` → `LayoutBefore`, last `dump_layout` → `LayoutAfter`.
- Status JSON enum: `missing` | `installed` | `up_to_date` | `outdated`.
- UI badge title values (v1): `Missing`, `Installed`, `Up to date`, `Outdated`.
- v1 window install scope is global only (`req.Global = true` for click-install leaves).
- Reuses the same content-comparison logic as `install --dry-run` / `checkAndWrite`.

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
)

const (
	actionIntegrationsJSON = "integrations_json"
	axErrorAPIDisabled     = "-25211"
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
	_, _ = stdin.Write(reqJSON)
	_, _ = stdin.Write([]byte("\n"))
	stdin.Close()

	if err := cmd.Wait(); err != nil {
		combined := strings.TrimSpace(stdout.String() + "\n" + stderr.String())
		if strings.Contains(combined, axErrorAPIDisabled) {
			t.Skip("Accessibility API disabled (kAXErrorAPIDisabled); enable Accessibility for test runner")
		}
		return nil, fmt.Errorf("ui-automation-helper failed: %w\nstdout: %s\nstderr: %s", err, stdout.String(), stderr.String())
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