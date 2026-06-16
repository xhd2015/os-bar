## Preconditions
- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..")` (parent of `tests/`).
- Bundled integration scripts are embedded via `//go:embed` in the production binary.
- **Isolation (mandatory):** Every test runs in isolated temporary directories. `Run` sets `HOME` to a dedicated `fakeHome` temp dir (never the real user home). Local installs use a separate `workDir` as `cmd.Dir`. Global installs resolve paths under `fakeHome` only.
- `os.UserHomeDir()` must resolve to `fakeHome` during each test because `HOME` is overridden via `t.Setenv`.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps
1. Create `fakeHome := filepath.Join(t.TempDir(), "home")` and `workDir := filepath.Join(t.TempDir(), "proj")`; `MkdirAll` both with mode `0755`.
2. Build the CLI **before** overriding `HOME` (avoids go telemetry writes into fakeHome).
3. `t.Setenv("HOME", fakeHome)` — required before running install; install `cmd.Env` inherits this override.
4. If `req.PreExistingHooksJSON` is non-empty, write it to the codex `hooks.json` path (global → `fakeHome/.codex/hooks.json`, local → `workDir/.codex/hooks.json`) before running install.
5. If `req.PreExistingGrokHooksJSON` is non-empty, write it to `<base>/.grok/hooks/<PreExistingGrokHookFile>` before running install.
6. Construct install args from `req` and run `<binary> install ...` with `cmd.Dir = workDir` and `cmd.Env = os.Environ()`.
7. If `req.RunTwice`, run install a second time; store second-run stdout in `StdoutSecond`.
8. Snapshot expected output paths under `fakeHome` and/or `workDir` into `Files` and `ScriptExecutable`.
9. Return `(*Response, nil)` with `FakeHome` and `WorkDir` populated for isolation asserts.

## Context
- `Action` is always `"install"` for this suite.
- `Target` is one of `"grok"`, `"codex"`, `"pi"`, `"opencode"`, or empty (validation only).
- Codex merge tests pre-seed `hooks.json` via `PreExistingHooksJSON` or load fixtures from `testdata/`.
- Grok coexistence tests pre-seed a separate hook file via `PreExistingGrokHookFile` + `PreExistingGrokHooksJSON`.
- Agent-sessions hook entries use `statusMessage: "os-bar agent-sessions notify"`.
- Codex `mergeCodexHooks` preserves foreign hooks; only our statusMessage entries are upserted.
- OpenCode local installs must not print the stale `/config add plugin` hint (that hint is global-only).
- `.sh` hook scripts are installed with mode `0755`.

```go
import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const agentSessionsHookStatus = "os-bar agent-sessions notify"

// Request drives a single install invocation. Defined only at root; descendants must not redefine.
type Request struct {
	Action               string // "install"
	Target               string // "grok" | "codex" | "pi" | "opencode" | ""
	Global               bool
	DryRun               bool
	PreExistingHooksJSON     string // write to hooks.json before install (codex merge tests)
	PreExistingGrokHookFile  string // filename under .grok/hooks/ (grok coexistence tests)
	PreExistingGrokHooksJSON string // content for PreExistingGrokHookFile
	RunTwice                 bool   // run install twice (idempotent tests)
}

// Response captures CLI outcome and filesystem snapshots.
type Response struct {
	ExitCode         int
	Stdout           string
	StdoutSecond     string // populated when RunTwice is true
	Stderr           string
	Files            map[string]string // absolute path → content or "MISSING"
	ScriptExecutable map[string]bool   // path → is executable
	FakeHome         string
	WorkDir          string
	Error            string
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

	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..")
	binaryPath := filepath.Join(t.TempDir(), "agent-sessions")
	buildCmd := exec.Command("go", "build", "-o", binaryPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("go build failed: %w\n%s", err, out)
	}

	t.Setenv("HOME", fakeHome)

	if req.PreExistingHooksJSON != "" {
		hooksPath := codexHooksJSONPath(req.Global, fakeHome, workDir)
		if err := os.MkdirAll(filepath.Dir(hooksPath), 0755); err != nil {
			return nil, fmt.Errorf("mkdir preexisting hooks dir: %w", err)
		}
		if err := os.WriteFile(hooksPath, []byte(req.PreExistingHooksJSON), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting hooks.json: %w", err)
		}
	}

	if req.PreExistingGrokHooksJSON != "" {
		filename := req.PreExistingGrokHookFile
		if filename == "" {
			filename = "other-hooks.json"
		}
		base := workDir
		if req.Global {
			base = fakeHome
		}
		hooksPath := filepath.Join(base, ".grok", "hooks", filename)
		if err := os.MkdirAll(filepath.Dir(hooksPath), 0755); err != nil {
			return nil, fmt.Errorf("mkdir preexisting grok hooks dir: %w", err)
		}
		if err := os.WriteFile(hooksPath, []byte(req.PreExistingGrokHooksJSON), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting grok hook file: %w", err)
		}
	}

	args := buildInstallArgs(req)
	run := func() (stdout, stderr string, exitCode int) {
		cmd := exec.Command(binaryPath, args...)
		cmd.Dir = workDir
		cmd.Env = os.Environ()
		var stdoutBuf, stderrBuf strings.Builder
		cmd.Stdout = &stdoutBuf
		cmd.Stderr = &stderrBuf
		err := cmd.Run()
		code := 0
		if err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				code = exitErr.ExitCode()
			} else {
				return "", "", -1
			}
		}
		return stdoutBuf.String(), stderrBuf.String(), code
	}

	stdout, stderr, exitCode := run()
	stdoutSecond := ""
	if req.RunTwice {
		stdoutSecond, _, _ = run()
	}

	paths := expectedPaths(req, fakeHome, workDir)
	files, execMap := snapshotFiles(paths)

	return &Response{
		ExitCode:         exitCode,
		Stdout:           stdout,
		StdoutSecond:     stdoutSecond,
		Stderr:           stderr,
		Files:            files,
		ScriptExecutable: execMap,
		FakeHome:         fakeHome,
		WorkDir:          workDir,
	}, nil
}

func buildInstallArgs(req *Request) []string {
	args := []string{"install"}
	if req.Target != "" {
		args = append(args, "--"+req.Target)
	}
	if req.Global {
		args = append(args, "--global")
	}
	if req.DryRun {
		args = append(args, "--dry-run")
	}
	return args
}

func codexHooksJSONPath(global bool, fakeHome, workDir string) string {
	if global {
		return filepath.Join(fakeHome, ".codex", "hooks.json")
	}
	return filepath.Join(workDir, ".codex", "hooks.json")
}

func expectedPaths(req *Request, fakeHome, workDir string) []string {
	if req.Target == "" {
		return nil
	}
	base := workDir
	if req.Global {
		base = fakeHome
	}
	switch req.Target {
	case "grok":
		return []string{
			filepath.Join(base, ".grok", "hooks", "agent-sessions.json"),
			filepath.Join(base, ".grok", "hooks", "bin", "agent-sessions-stop.sh"),
		}
	case "codex":
		return []string{
			filepath.Join(base, ".codex", "hooks.json"),
			filepath.Join(base, ".codex", "hooks", "agent-sessions-stop.sh"),
		}
	case "opencode":
		if req.Global {
			return []string{filepath.Join(fakeHome, ".config", "opencode", "plugins", "agent-sessions.ts")}
		}
		return []string{filepath.Join(workDir, ".opencode", "plugins", "agent-sessions.ts")}
	case "pi":
		if req.Global {
			return []string{filepath.Join(fakeHome, ".pi", "agent", "extensions", "agent-sessions-hook.ts")}
		}
		return []string{filepath.Join(workDir, ".pi", "extensions", "agent-sessions-hook.ts")}
	default:
		return nil
	}
}

// fileContent returns snapshot content or "MISSING" when the path was not written.
func fileContent(resp *Response, path string) string {
	if content, ok := resp.Files[path]; ok {
		return content
	}
	return "MISSING"
}

// samePath compares paths after Abs+EvalSymlinks (handles /var vs /private/var on macOS).
func samePath(t *testing.T, a, b string) bool {
	t.Helper()
	norm := func(p string) string {
		abs, err := filepath.Abs(p)
		if err != nil {
			t.Fatalf("abs %q: %v", p, err)
		}
		resolved, err := filepath.EvalSymlinks(abs)
		if err != nil {
			return abs
		}
		return resolved
	}
	return norm(a) == norm(b)
}

func snapshotFiles(paths []string) (map[string]string, map[string]bool) {
	files := make(map[string]string)
	execMap := make(map[string]bool)
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			files[p] = "MISSING"
			continue
		}
		files[p] = string(data)
		if strings.HasSuffix(p, ".sh") {
			if info, err := os.Stat(p); err == nil {
				execMap[p] = info.Mode().Perm()&0111 != 0
			}
		}
	}
	return files, execMap
}

// assertPathIsolated fails if path is not under fakeHome or workDir.
func assertPathIsolated(t *testing.T, path, fakeHome, workDir string) {
	t.Helper()
	absPath, err := filepath.Abs(path)
	if err != nil {
		t.Fatalf("abs path %q: %v", path, err)
	}
	homeAbs, _ := filepath.Abs(fakeHome)
	workAbs, _ := filepath.Abs(workDir)
	if !strings.HasPrefix(absPath, homeAbs+string(filepath.Separator)) &&
		!strings.HasPrefix(absPath, workAbs+string(filepath.Separator)) &&
		absPath != homeAbs && absPath != workAbs {
		t.Fatalf("path %q is outside isolated dirs (fakeHome=%q, workDir=%q)", absPath, fakeHome, workDir)
	}
}

func assertNoFilesUnderDir(t *testing.T, root string) {
	t.Helper()
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if path == root {
			return nil
		}
		if !info.IsDir() {
			t.Fatalf("unexpected file under isolated dir %q: %s", root, path)
		}
		return nil
	})
}

func assertNoFilesCreated(t *testing.T, resp *Response) {
	t.Helper()
	for path, content := range resp.Files {
		if content != "MISSING" {
			t.Fatalf("expected no files, but %q exists", path)
		}
	}
	assertNoFilesUnderDir(t, resp.FakeHome)
	assertNoFilesUnderDir(t, resp.WorkDir)
}

func parseCodexHooks(t *testing.T, jsonText string) map[string][]json.RawMessage {
	t.Helper()
	var file struct {
		Hooks map[string][]json.RawMessage `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(jsonText), &file); err != nil {
		t.Fatalf("parse hooks.json: %v", err)
	}
	if file.Hooks == nil {
		file.Hooks = make(map[string][]json.RawMessage)
	}
	return file.Hooks
}

func countCodexStopGroups(t *testing.T, jsonText string) int {
	t.Helper()
	hooks := parseCodexHooks(t, jsonText)
	return len(hooks["Stop"])
}

func countOurStopHandlers(t *testing.T, jsonText string) int {
	t.Helper()
	hooks := parseCodexHooks(t, jsonText)
	count := 0
	for _, groupRaw := range hooks["Stop"] {
		var group struct {
			Hooks []struct {
				StatusMessage string `json:"statusMessage"`
			} `json:"hooks"`
		}
		if err := json.Unmarshal(groupRaw, &group); err != nil {
			t.Fatalf("parse Stop group: %v", err)
		}
		for _, h := range group.Hooks {
			if h.StatusMessage == agentSessionsHookStatus {
				count++
			}
		}
	}
	return count
}

func grokHooksHasStop(t *testing.T, jsonText string) bool {
	t.Helper()
	var file struct {
		Hooks map[string]json.RawMessage `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(jsonText), &file); err != nil {
		t.Fatalf("parse grok hooks: %v", err)
	}
	_, ok := file.Hooks["Stop"]
	return ok
}
```