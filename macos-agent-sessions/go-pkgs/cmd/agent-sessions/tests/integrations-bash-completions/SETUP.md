# Scenario

**Feature**: integrations help examples and bash-completions install subcommand

```
# CLI exec under isolated HOME
test harness -> agent-sessions binary -> stdout/stderr + exit code

# bash-completions --install writes embedded script and sources it from bash profile
agent-sessions integrations bash-completions --install -> completion file + bash profile

# integrations default prints human-readable table for both scopes
agent-sessions integrations -> Integrations: dual-scope table on stdout

# scope filters narrow listing to one scope
agent-sessions integrations --global -> Integrations (global): table
agent-sessions integrations --local -> Integrations (local): table

# integrations --json lists integration status (scope flags control entry count)
agent-sessions integrations --json -> JSON with global+local entries
agent-sessions integrations --json --global -> JSON integrations list (4 global)
```

## Preconditions

- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..")`.
- Bash completion script content is embedded via `//go:embed` in the production binary.
- **Isolation (mandatory):** Every test runs in isolated temporary directories. `Run` sets `HOME` to a dedicated `fakeHome` temp dir (never the real user home). Commands run with `cmd.Dir = workDir`.
- Completion script path: `<fakeHome>/.config/agent-sessions/bash-completion.bash`.
- Bash profile path (macOS bash): `<fakeHome>/.bash_profile`.
- Profile source detection substring: `.config/agent-sessions/bash-completion.bash`.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Create `fakeHome` and `workDir` under `t.TempDir()`; `MkdirAll` both with mode `0755`.
2. Build the CLI **before** overriding `HOME`.
3. `t.Setenv("HOME", fakeHome)`.
4. If `req.PreExistingCompletion` is non-empty, write it to the completion path (creating parent dirs).
5. If `req.PreExistingProfile` is non-empty, write it to the bash profile path.
6. If `req.SeedMatchingCompletion`, run `integrations bash-completions --install` once to seed bundled content.
7. Construct CLI args from `req` and exec the binary; capture stdout, stderr, exit code.
8. If `req.RunTwice`, run the same command a second time; store stdout in `StdoutSecond`.
9. If `req.CaptureHelpReference`, exec `integrations bash-completions --help` and store stdout.
10. Snapshot completion file and bash profile into `Files`.
11. Return `(*Response, nil)` with `FakeHome`, `WorkDir`, `CompletionPath`, and `ProfilePath` populated.

## Context

- `Action` is `"integrations"` for top-level integrations commands, or `"integrations_bash_completions"` for the nested subcommand.
- `JsonOut` adds `--json` for machine-readable output; when false, `integrations` prints a human-readable table (default).
- `Global` adds `--global` to include global install locations.
- `Local` adds `--local` to include project-local install locations.
- With neither flag, both scopes are listed (default). With both flags, same as default.
- `SeedGrokViaInstall` runs `install --grok --global` before the main command (mixed-status human output tests).
- `SeedGrokLocal` runs `install --grok` (project-local) before the main command.
- `Install` and `DryRun` apply to bash-completions only.
- `PreExistingCompletion` pre-seeds the completion path before the main command.
- `PreExistingProfile` pre-seeds `~/.bash_profile` before the main command.
- `SeedMatchingCompletion` installs bundled content first (for dry-run on matching file).
- Stale pre-seed content uses the constant `staleCompletionContent`.
- Profile append block (when substring absent):
  ```
  # agent-sessions bash completion
  [[ -f "$HOME/.config/agent-sessions/bash-completion.bash" ]] && source "$HOME/.config/agent-sessions/bash-completion.bash"
  ```

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

const staleCompletionContent = "# stale agent-sessions bash completion\ncomplete -F _stale agent-sessions\n"

const profileSourceSubstring = ".config/agent-sessions/bash-completion.bash"

const profileSourceMarker = "# agent-sessions bash completion"

// Request drives a single CLI invocation. Defined only at root; descendants must not redefine.
type Request struct {
	Action                 string   // "integrations" | "integrations_bash_completions"
	Args                   []string // extra CLI args after flags
	JsonOut                bool     // integrations --json
	Global                 bool     // integrations --global
	Local                  bool     // integrations --local
	SeedGrokViaInstall     bool     // run install --grok --global before main command
	SeedGrokLocal          bool     // run install --grok (local) before main command
	DryRun                 bool     // bash-completions --dry-run
	Install                bool     // bash-completions --install
	PreExistingCompletion  string   // write to completion path before run
	PreExistingProfile     string   // write to bash profile before run
	RunTwice               bool     // run command twice (idempotent tests)
	SeedMatchingCompletion bool     // install bundled content before main command
	CaptureHelpReference   bool     // capture bash-completions --help stdout
}

// Response captures CLI outcome and filesystem snapshots.
type Response struct {
	ExitCode            int
	Stdout              string
	StdoutSecond        string
	Stderr              string
	Files               map[string]string // absolute path → content or "MISSING"
	FakeHome            string
	WorkDir             string
	CompletionPath      string
	ProfilePath         string
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
	profilePath := profilePath(fakeHome)

	if req.PreExistingCompletion != "" {
		if err := os.MkdirAll(filepath.Dir(completionPath), 0755); err != nil {
			return nil, fmt.Errorf("mkdir preexisting completion dir: %w", err)
		}
		if err := os.WriteFile(completionPath, []byte(req.PreExistingCompletion), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting completion: %w", err)
		}
	}

	if req.PreExistingProfile != "" {
		if err := os.WriteFile(profilePath, []byte(req.PreExistingProfile), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting profile: %w", err)
		}
	}

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

	if req.SeedMatchingCompletion {
		seedArgs := []string{"integrations", "bash-completions", "--install"}
		if _, _, code := execCLI(seedArgs); code != 0 {
			return nil, fmt.Errorf("seed install failed with exit code %d", code)
		}
	}

	if req.SeedGrokViaInstall {
		seedArgs := []string{"install", "--grok", "--global"}
		if _, _, code := execCLI(seedArgs); code != 0 {
			return nil, fmt.Errorf("seed grok global install failed with exit code %d", code)
		}
	}

	if req.SeedGrokLocal {
		seedArgs := []string{"install", "--grok"}
		if _, _, code := execCLI(seedArgs); code != 0 {
			return nil, fmt.Errorf("seed grok local install failed with exit code %d", code)
		}
	}

	args := buildIntegrationsArgs(req)
	stdout, stderr, exitCode := execCLI(args)

	stdoutSecond := ""
	if req.RunTwice {
		stdoutSecond, _, _ = execCLI(args)
	}

	helpRef := ""
	if req.CaptureHelpReference {
		helpRef, _, _ = execCLI([]string{"integrations", "bash-completions", "--help"})
	}

	files := snapshotInstallFiles(completionPath, profilePath)

	return &Response{
		ExitCode:            exitCode,
		Stdout:              stdout,
		StdoutSecond:        stdoutSecond,
		Stderr:              stderr,
		Files:               files,
		FakeHome:            fakeHome,
		WorkDir:             workDir,
		CompletionPath:      completionPath,
		ProfilePath:         profilePath,
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
		if req.Local {
			args = append(args, "--local")
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

func profilePath(fakeHome string) string {
	return filepath.Join(fakeHome, ".bash_profile")
}

func snapshotInstallFiles(completionPath, profilePath string) map[string]string {
	files := make(map[string]string)
	for _, path := range []string{completionPath, profilePath} {
		data, err := os.ReadFile(path)
		if err != nil {
			files[path] = "MISSING"
			continue
		}
		files[path] = string(data)
	}
	return files
}

func assertPathUnderFakeHome(t *testing.T, path, fakeHome string) {
	t.Helper()
	absPath, err := filepath.Abs(path)
	if err != nil {
		t.Fatalf("abs path %q: %v", path, err)
	}
	homeAbs, err := filepath.Abs(fakeHome)
	if err != nil {
		t.Fatalf("abs fakeHome %q: %v", fakeHome, err)
	}
	if !strings.HasPrefix(absPath, homeAbs+string(filepath.Separator)) && absPath != homeAbs {
		t.Fatalf("path %q is outside fakeHome %q", absPath, homeAbs)
	}
}

func fileContent(path string, resp *Response) string {
	if content, ok := resp.Files[path]; ok {
		return content
	}
	return "MISSING"
}

func completionContent(path string, resp *Response) string {
	return fileContent(path, resp)
}

func profileContent(path string, resp *Response) string {
	return fileContent(path, resp)
}

func profileHasSourceLine(content string) bool {
	return strings.Contains(content, profileSourceSubstring)
}

func assertProfileUnchanged(t *testing.T, req *Request, resp *Response) {
	t.Helper()
	if req.PreExistingProfile == "" {
		return
	}
	got := profileContent(resp.ProfilePath, resp)
	if got != req.PreExistingProfile {
		t.Fatalf("profile was modified:\nwant %q\ngot %q", req.PreExistingProfile, got)
	}
}

func hasCompletionMarkers(t *testing.T, content string) bool {
	t.Helper()
	markers := []string{
		"agent-sessions",
		"notify",
		"list",
		"status",
		"integrations",
		"install",
		"logs",
		"remove",
		"watch",
		"serve",
	}
	for _, m := range markers {
		if !strings.Contains(content, m) {
			return false
		}
	}
	return true
}

type integrationJSONEntry struct {
	ID     string `json:"id"`
	Scope  string `json:"scope"`
	Status string `json:"status"`
}

func parseIntegrationsJSON(t *testing.T, stdout string) struct {
	Integrations []integrationJSONEntry `json:"integrations"`
} {
	t.Helper()
	var out struct {
		Integrations []integrationJSONEntry `json:"integrations"`
	}
	if err := json.Unmarshal([]byte(stdout), &out); err != nil {
		t.Fatalf("parse integrations JSON: %v\nstdout=%q", err, stdout)
	}
	return out
}

var integrationOrder = []string{"grok", "opencode", "pi", "codex"}

var knownHumanStatusLabels = []string{"Missing", "Up to date", "Outdated"}

func assertNoJSONOutput(t *testing.T, stdout string) {
	t.Helper()
	trimmed := strings.TrimSpace(stdout)
	if strings.HasPrefix(trimmed, "{") || strings.HasPrefix(trimmed, "[") {
		t.Fatalf("stdout looks like JSON: %q", stdout)
	}
	if strings.Contains(stdout, `"integrations"`) {
		t.Fatalf("stdout contains JSON field integrations: %q", stdout)
	}
}

func assertHumanScopeHeader(t *testing.T, stdout, scope string) {
	t.Helper()
	want := fmt.Sprintf("Integrations (%s):", scope)
	if !strings.Contains(stdout, want) {
		t.Fatalf("stdout missing header %q; got:\n%s", want, stdout)
	}
}

func assertDualScopeHeader(t *testing.T, stdout string) {
	t.Helper()
	lines := strings.Split(stdout, "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "Integrations:" {
			return
		}
		if strings.HasPrefix(trimmed, "Integrations (") {
			t.Fatalf("dual-scope stdout must use bare Integrations: header, not scoped; got:\n%s", stdout)
		}
	}
	t.Fatalf("stdout missing dual-scope header Integrations:; got:\n%s", stdout)
}

func assertNoScopeSuffixes(t *testing.T, stdout string) {
	t.Helper()
	for _, suffix := range []string{"(Global)", "(Local)", "(Global + Local)"} {
		if strings.Contains(stdout, suffix) {
			t.Fatalf("single-scope stdout must not contain scope suffix %q; got:\n%s", suffix, stdout)
		}
	}
}

func assertIntegrationOrder(t *testing.T, stdout string) {
	t.Helper()
	last := -1
	for _, id := range integrationOrder {
		pos := strings.Index(stdout, id)
		if pos < 0 {
			t.Fatalf("stdout missing integration id %q; got:\n%s", id, stdout)
		}
		if pos <= last {
			t.Fatalf("integration %q out of order (pos=%d, last=%d); stdout:\n%s", id, pos, last, stdout)
		}
		last = pos
	}
}

func integrationLines(stdout, id string) []string {
	var matches []string
	for _, line := range strings.Split(stdout, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, id+" ") || strings.HasPrefix(trimmed, id+"\t") {
			matches = append(matches, trimmed)
		}
	}
	return matches
}

func integrationLine(stdout, id string) string {
	lines := integrationLines(stdout, id)
	if len(lines) == 0 {
		return ""
	}
	return lines[0]
}

func integrationTableRows(stdout string) []string {
	var rows []string
	for _, line := range strings.Split(stdout, "\n") {
		trimmed := strings.TrimSpace(line)
		for _, id := range integrationOrder {
			if strings.HasPrefix(trimmed, id+" ") || strings.HasPrefix(trimmed, id+"\t") {
				rows = append(rows, trimmed)
				break
			}
		}
	}
	return rows
}

func countAllIntegrationRows(t *testing.T, stdout string) int {
	t.Helper()
	return len(integrationTableRows(stdout))
}

func assertDualScopeAllMissing(t *testing.T, stdout string) {
	t.Helper()
	assertDualScopeHeader(t, stdout)
	rows := integrationTableRows(stdout)
	if len(rows) != 8 {
		t.Fatalf("expected 8 dual-scope rows (4 agents × 2 scopes), got %d; stdout:\n%s", len(rows), stdout)
	}
	wantOrder := []struct {
		id     string
		suffix string
	}{
		{"grok", "(Global)"}, {"grok", "(Local)"},
		{"opencode", "(Global)"}, {"opencode", "(Local)"},
		{"pi", "(Global)"}, {"pi", "(Local)"},
		{"codex", "(Global)"}, {"codex", "(Local)"},
	}
	for i, want := range wantOrder {
		if i >= len(rows) {
			break
		}
		row := rows[i]
		if !strings.HasPrefix(row, want.id+" ") && !strings.HasPrefix(row, want.id+"\t") {
			t.Fatalf("row %d want id %q, got %q", i, want.id, row)
		}
		if !strings.Contains(row, "Missing") || !strings.Contains(row, want.suffix) {
			t.Fatalf("row %d want Missing %s, got %q", i, want.suffix, row)
		}
	}
}

func countIntegrationLines(t *testing.T, stdout string) int {
	t.Helper()
	count := 0
	for _, id := range integrationOrder {
		if integrationLine(stdout, id) != "" {
			count++
		}
	}
	return count
}

func assertLineHasHumanLabel(t *testing.T, stdout, id string) {
	t.Helper()
	line := integrationLine(stdout, id)
	if line == "" {
		t.Fatalf("stdout missing row for integration %q; got:\n%s", id, stdout)
	}
	hasLabel := false
	for _, label := range knownHumanStatusLabels {
		if strings.Contains(line, label) {
			hasLabel = true
			break
		}
	}
	if !hasLabel {
		t.Fatalf("row for %q missing human status label; line=%q", id, line)
	}
}

func assertHumanStatusLabels(t *testing.T, stdout string, idToLabel map[string]string) {
	t.Helper()
	for id, label := range idToLabel {
		line := integrationLine(stdout, id)
		if line == "" {
			t.Fatalf("stdout missing row for %q; got:\n%s", id, stdout)
		}
		if !strings.Contains(line, label) {
			t.Fatalf("row for %q want label %q; line=%q", id, label, line)
		}
	}
}

func assertJSONScopes(t *testing.T, stdout string, wantCount int, allowedScopes map[string]bool) {
	t.Helper()
	out := parseIntegrationsJSON(t, stdout)
	if len(out.Integrations) != wantCount {
		t.Fatalf("expected %d integrations, got %d: %v", wantCount, len(out.Integrations), out.Integrations)
	}
	scopeCounts := make(map[string]int)
	for _, entry := range out.Integrations {
		if entry.Scope == "" {
			t.Fatalf("integration %q missing scope field", entry.ID)
		}
		if !allowedScopes[entry.Scope] {
			t.Fatalf("integration %q has unexpected scope %q; allowed=%v", entry.ID, entry.Scope, allowedScopes)
		}
		scopeCounts[entry.Scope]++
	}
	for scope := range allowedScopes {
		if scopeCounts[scope] == 0 {
			t.Fatalf("expected at least one entry with scope %q; got counts=%v", scope, scopeCounts)
		}
	}
}
```