# Scenario

**Feature**: integrations nested agent subcommands route to existing install logic

```
# CLI exec under isolated HOME and workDir
test harness -> agent-sessions binary -> stdout/stderr + exit code

# integrations dispatches to agent subcommands (codex, grok, pi, opencode)
agent-sessions integrations <agent> --install -> InstallCodex/InstallGrok/CheckAndWrite

# integrations --json unchanged for API consumers
agent-sessions integrations --json --global -> JSON integrations list

# bash-completions subcommand still routes correctly
agent-sessions integrations bash-completions --install --dry-run -> would install message
```

## Preconditions

- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..")`.
- Integration scripts are embedded via `//go:embed` in the production binary.
- **Isolation (mandatory):** Every test runs in isolated temporary directories. `Run` sets `HOME` to a dedicated `fakeHome` temp dir (never the real user home). Commands run with `cmd.Dir = workDir`.
- `os.UserHomeDir()` must resolve to `fakeHome` during each test because `HOME` is overridden via `t.Setenv`.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Create `fakeHome` and `workDir` under `t.TempDir()`; `MkdirAll` both with mode `0755`.
2. Build the CLI **before** overriding `HOME`.
3. `t.Setenv("HOME", fakeHome)`.
4. Construct CLI args from `req` and exec the binary; capture stdout, stderr, exit code.
5. If `req.CaptureHelpReference`, exec agent subcommand `--help` and store stdout.
6. Snapshot agent install paths (when `req.Agent` is set) and bash completion path into `Files`.
7. Return `(*Response, nil)` with `FakeHome`, `WorkDir`, and path fields populated.

## Context

- `Action` is `"integrations"` for top-level integrations commands,
  `"integrations_agent"` for agent subcommands (`codex`, `grok`, `pi`, `opencode`),
  or `"integrations_bash_completions"` for the bash-completions subcommand.
- `Agent` is one of `"codex"`, `"grok"`, `"pi"`, `"opencode"` when `Action` is
  `integrations_agent`.
- `JsonOut` adds `--json` for machine-readable output.
- `Global` adds `--global` for global install locations.
- `Install` and `DryRun` apply to agent subcommands and bash-completions.
- Agent hook entries use `statusMessage: "os-bar agent-sessions notify"`.
- Completion script path: `<fakeHome>/.config/agent-sessions/bash-completion.bash`.

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

// Request drives a single CLI invocation. Defined only at root; descendants must not redefine.
type Request struct {
	Action               string   // "integrations" | "integrations_agent" | "integrations_bash_completions"
	Agent                string   // "codex" | "grok" | "pi" | "opencode"
	Args                 []string // extra CLI args after flags
	JsonOut              bool     // integrations --json
	Global               bool     // --global
	Install              bool     // agent/bash-completions --install
	DryRun               bool     // agent/bash-completions --dry-run
	CaptureHelpReference bool     // capture agent --help stdout for comparison
}

// Response captures CLI outcome and filesystem snapshots.
type Response struct {
	ExitCode            int
	Stdout              string
	Stderr              string
	Files               map[string]string // absolute path → content or "MISSING"
	ScriptExecutable    map[string]bool   // path → is executable (.sh scripts)
	FakeHome            string
	WorkDir             string
	CompletionPath      string
	HelpReferenceStdout string
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
	completionPath := completionPath(fakeHome)

	execCLI := func(args []string) (stdout, stderr string, exitCode int) {
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

	args := buildIntegrationsArgs(req)
	stdout, stderr, exitCode := execCLI(args)

	helpRef := ""
	if req.CaptureHelpReference && req.Agent != "" {
		helpArgs := []string{"integrations", req.Agent, "--help"}
		helpRef, _, _ = execCLI(helpArgs)
	}

	paths := expectedAgentPaths(req, fakeHome, workDir)
	if req.Action == "integrations_bash_completions" {
		paths = append(paths, completionPath)
	}
	files, execMap := snapshotFiles(paths)

	return &Response{
		ExitCode:            exitCode,
		Stdout:              stdout,
		Stderr:              stderr,
		Files:               files,
		ScriptExecutable:    execMap,
		FakeHome:            fakeHome,
		WorkDir:             workDir,
		CompletionPath:      completionPath,
		HelpReferenceStdout: helpRef,
	}, nil
}

func buildIntegrationsArgs(req *Request) []string {
	switch req.Action {
	case "integrations":
		args := []string{"integrations"}
		if req.JsonOut {
			args = append(args, "--json")
		}
		if req.Global {
			args = append(args, "--global")
		}
		args = append(args, req.Args...)
		return args
	case "integrations_agent":
		args := []string{"integrations", req.Agent}
		if req.Install {
			args = append(args, "--install")
		}
		if req.DryRun {
			args = append(args, "--dry-run")
		}
		if req.Global {
			args = append(args, "--global")
		}
		args = append(args, req.Args...)
		return args
	case "integrations_bash_completions":
		args := []string{"integrations", "bash-completions"}
		if req.Install {
			args = append(args, "--install")
		}
		if req.DryRun {
			args = append(args, "--dry-run")
		}
		args = append(args, req.Args...)
		return args
	default:
		return []string{"integrations"}
	}
}

func completionPath(fakeHome string) string {
	return filepath.Join(fakeHome, ".config", "agent-sessions", "bash-completion.bash")
}

func expectedAgentPaths(req *Request, fakeHome, workDir string) []string {
	if req.Agent == "" {
		return nil
	}
	base := workDir
	if req.Global {
		base = fakeHome
	}
	switch req.Agent {
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

func fileContent(resp *Response, path string) string {
	if content, ok := resp.Files[path]; ok {
		return content
	}
	return "MISSING"
}

func completionContent(resp *Response) string {
	return fileContent(resp, resp.CompletionPath)
}

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

func parseIntegrationsJSON(t *testing.T, stdout string) struct {
	Integrations []struct {
		ID string `json:"id"`
	} `json:"integrations"`
} {
	t.Helper()
	var out struct {
		Integrations []struct {
			ID string `json:"id"`
		} `json:"integrations"`
	}
	if err := json.Unmarshal([]byte(stdout), &out); err != nil {
		t.Fatalf("parse integrations JSON: %v\nstdout=%q", err, stdout)
	}
	return out
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
```