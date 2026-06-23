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
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/xhd2015/dot-pkgs/go-pkgs/pathfmt"
)

const agentSessionsHookStatus = "os-bar agent-sessions notify"

const codexGlobalHintCommand = "agent-sessions integrations codex --install --global"

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

func withHumanDisplayEnv(t *testing.T, resp *Response, fn func()) {
	t.Helper()
	orig, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	t.Cleanup(func() { _ = os.Chdir(orig) })
	t.Setenv("HOME", resp.FakeHome)
	if err := os.Chdir(resp.WorkDir); err != nil {
		t.Fatalf("chdir workDir %q: %v", resp.WorkDir, err)
	}
	fn()
}

func humanDisplayPath(t *testing.T, resp *Response, absPath string) string {
	t.Helper()
	var result string
	withHumanDisplayEnv(t, resp, func() {
		result = pathfmt.Short(absPath)
	})
	return result
}

func codexHooksPath(resp *Response, global bool) string {
	base := resp.WorkDir
	if global {
		base = resp.FakeHome
	}
	return filepath.Join(base, ".codex", "hooks.json")
}

func codexScriptPath(resp *Response, global bool) string {
	base := resp.WorkDir
	if global {
		base = resp.FakeHome
	}
	return filepath.Join(base, ".codex", "hooks", "agent-sessions-stop.sh")
}

func assertNoAbsoluteTempPaths(t *testing.T, stdout string, resp *Response) {
	t.Helper()
	for _, prefix := range []string{resp.FakeHome, resp.WorkDir} {
		if prefix != "" && strings.Contains(stdout, prefix) {
			t.Fatalf("stdout must not contain absolute temp path %q; got:\n%s", prefix, stdout)
		}
	}
	if strings.Contains(stdout, "/var/folders/") || strings.Contains(stdout, "/private/var/folders/") {
		t.Fatalf("stdout must not contain macOS temp dir prefix; got:\n%s", stdout)
	}
}

func assertStdoutContainsShortenedPath(t *testing.T, stdout, absPath string, resp *Response) {
	t.Helper()
	want := humanDisplayPath(t, resp, absPath)
	if !strings.Contains(stdout, want) {
		t.Fatalf("stdout want shortened path %q; got:\n%s", want, stdout)
	}
}

func assertCodexInstallStdoutShortened(t *testing.T, stdout string, resp *Response, global bool) {
	t.Helper()
	assertStdoutContainsShortenedPath(t, stdout, codexScriptPath(resp, global), resp)
	assertStdoutContainsShortenedPath(t, stdout, codexHooksPath(resp, global), resp)
	assertNoAbsoluteTempPaths(t, stdout, resp)
}

func assertCodexGlobalHint(t *testing.T, stdout string) {
	t.Helper()
	if !strings.Contains(stdout, "To install globally, run:") {
		t.Fatalf("stdout missing global install hint; got:\n%s", stdout)
	}
	if !strings.Contains(stdout, codexGlobalHintCommand) {
		t.Fatalf("stdout missing hint command %q; got:\n%s", codexGlobalHintCommand, stdout)
	}
}

func assertNoCodexGlobalHint(t *testing.T, stdout string) {
	t.Helper()
	if strings.Contains(stdout, "To install globally, run:") {
		t.Fatalf("stdout must not contain global install hint; got:\n%s", stdout)
	}
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