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
- `CorruptGrokLocalHooks` overwrites `<workDir>/.grok/hooks/agent-sessions.json` with stale JSON after grok seeds (dual-scope different-status tests).
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

	"github.com/xhd2015/dot-pkgs/go-pkgs/pathfmt"
)

const staleCompletionContent = "# stale agent-sessions bash completion\ncomplete -F _stale agent-sessions\n"

const profileSourceSubstring = ".config/agent-sessions/bash-completion.bash"

const profileSourceMarker = "# agent-sessions bash completion"

func Setup(t *testing.T, req *Request) error {
	t.Logf("integrations-bash-completions: shared harness ready")
	return nil
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

func withHumanDisplayEnv(t *testing.T, resp *Response, fn func()) {
	t.Helper()
	origWd, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	defer func() {
		if err := os.Chdir(origWd); err != nil {
			t.Fatalf("restore wd: %v", err)
		}
	}()
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

func integrationGlobalPath(resp *Response, id string) string {
	switch id {
	case "grok":
		return filepath.Join(resp.FakeHome, ".grok", "hooks", "agent-sessions.json")
	case "opencode":
		return filepath.Join(resp.FakeHome, ".config", "opencode", "plugins", "agent-sessions.ts")
	case "pi":
		return filepath.Join(resp.FakeHome, ".pi", "agent", "extensions", "agent-sessions-hook.ts")
	case "codex":
		return filepath.Join(resp.FakeHome, ".codex", "hooks.json")
	default:
		return ""
	}
}

func integrationLocalPath(resp *Response, id string) string {
	switch id {
	case "grok":
		return filepath.Join(resp.WorkDir, ".grok", "hooks", "agent-sessions.json")
	case "opencode":
		return filepath.Join(resp.WorkDir, ".opencode", "plugins", "agent-sessions.ts")
	case "pi":
		return filepath.Join(resp.WorkDir, ".pi", "extensions", "agent-sessions-hook.ts")
	case "codex":
		return filepath.Join(resp.WorkDir, ".codex", "hooks.json")
	default:
		return ""
	}
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

func assertHumanPathShortened(t *testing.T, stdout, line, absPath string, resp *Response) {
	t.Helper()
	want := humanDisplayPath(t, resp, absPath)
	if !strings.Contains(line, want) {
		t.Fatalf("line want shortened path %q; line=%q\nstdout:\n%s", want, line, stdout)
	}
	assertNoAbsoluteTempPaths(t, line, resp)
}

func assertDualScopeAllMissing(t *testing.T, stdout string, resp *Response) {
	t.Helper()
	assertDualScopeHeader(t, stdout)
	rows := integrationTableRows(stdout)
	if len(rows) != 4 {
		t.Fatalf("expected 4 dual-scope rows (4 agents, both scopes missing), got %d; stdout:\n%s", len(rows), stdout)
	}
	for i, id := range integrationOrder {
		if i >= len(rows) {
			break
		}
		row := rows[i]
		if !strings.HasPrefix(row, id+" ") && !strings.HasPrefix(row, id+"\t") {
			t.Fatalf("row %d want id %q, got %q", i, id, row)
		}
		if !strings.Contains(row, "Missing (Global + Local)") {
			t.Fatalf("row %d want Missing (Global + Local), got %q", i, row)
		}
		if strings.Contains(row, "(Global)") && !strings.Contains(row, "(Global + Local)") {
			t.Fatalf("row %d must not show separate Global row when both scopes missing; got %q", i, row)
		}
		if strings.Contains(row, "(Local)") && !strings.Contains(row, "(Global + Local)") {
			t.Fatalf("row %d must not show separate Local row when both scopes missing; got %q", i, row)
		}
		assertHumanPathShortened(t, stdout, row, integrationGlobalPath(resp, id), resp)
	}
	assertNoAbsoluteTempPaths(t, stdout, resp)
}

func assertDualScopeBothMissingAgent(t *testing.T, stdout, id string, resp *Response) {
	t.Helper()
	lines := integrationLines(stdout, id)
	if len(lines) != 1 {
		t.Fatalf("%s want 1 collapsed Missing (Global + Local) row, got %d: %v", id, len(lines), lines)
	}
	if !strings.Contains(lines[0], "Missing (Global + Local)") {
		t.Fatalf("%s want Missing (Global + Local); line=%q", id, lines[0])
	}
	assertHumanPathShortened(t, stdout, lines[0], integrationGlobalPath(resp, id), resp)
}

func assertSingleScopeHumanPaths(t *testing.T, stdout string, resp *Response, global bool) {
	t.Helper()
	for _, id := range integrationOrder {
		line := integrationLine(stdout, id)
		if line == "" {
			t.Fatalf("stdout missing row for %q; got:\n%s", id, stdout)
		}
		var absPath string
		if global {
			absPath = integrationGlobalPath(resp, id)
		} else {
			absPath = integrationLocalPath(resp, id)
		}
		assertHumanPathShortened(t, stdout, line, absPath, resp)
	}
	assertNoAbsoluteTempPaths(t, stdout, resp)
}

func assertJoinedHumanPaths(t *testing.T, stdout, line, globalAbs, localAbs string, resp *Response) {
	t.Helper()
	want := humanDisplayPath(t, resp, globalAbs) + " + " + humanDisplayPath(t, resp, localAbs)
	if !strings.Contains(line, want) {
		t.Fatalf("line want joined shortened paths %q; line=%q\nstdout:\n%s", want, line, stdout)
	}
	assertNoAbsoluteTempPaths(t, line, resp)
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