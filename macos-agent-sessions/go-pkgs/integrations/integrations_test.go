package integrations

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGrokHookPaths(t *testing.T) {
	home := "/home/user"
	cwd := "/proj"

	globalConfig, globalScript := GrokHookPaths(true, home, cwd)
	if globalConfig != filepath.Join(home, ".grok", "hooks", "agent-sessions.json") {
		t.Fatalf("global config path: got %q", globalConfig)
	}
	if globalScript != filepath.Join(home, ".grok", "hooks", "bin", "agent-sessions-stop.sh") {
		t.Fatalf("global script path: got %q", globalScript)
	}

	localConfig, localScript := GrokHookPaths(false, home, cwd)
	if localConfig != filepath.Join(cwd, ".grok", "hooks", "agent-sessions.json") {
		t.Fatalf("local config path: got %q", localConfig)
	}
	if localScript != filepath.Join(cwd, ".grok", "hooks", "bin", "agent-sessions-stop.sh") {
		t.Fatalf("local script path: got %q", localScript)
	}
}

func TestCodexHookPaths(t *testing.T) {
	home := "/home/user"
	cwd := "/proj"

	globalConfig, globalScript := CodexHookPaths(true, home, cwd)
	if globalConfig != filepath.Join(home, ".codex", "hooks.json") {
		t.Fatalf("global config path: got %q", globalConfig)
	}
	if globalScript != filepath.Join(home, ".codex", "hooks", "agent-sessions-stop.sh") {
		t.Fatalf("global script path: got %q", globalScript)
	}

	localConfig, localScript := CodexHookPaths(false, home, cwd)
	if localConfig != filepath.Join(cwd, ".codex", "hooks.json") {
		t.Fatalf("local config path: got %q", localConfig)
	}
	if localScript != filepath.Join(cwd, ".codex", "hooks", "agent-sessions-stop.sh") {
		t.Fatalf("local script path: got %q", localScript)
	}
}

func TestMergeCodexHooksEmpty(t *testing.T) {
	script := "/home/user/.codex/hooks/agent-sessions-stop.sh"
	merged, err := MergeCodexHooks(nil, codexHooksJSON, script)
	if err != nil {
		t.Fatalf("merge empty: %v", err)
	}

	var file hooksFile
	if err := json.Unmarshal(merged, &file); err != nil {
		t.Fatalf("unmarshal merged: %v", err)
	}
	if len(file.Hooks["Stop"]) != 1 {
		t.Fatalf("expected 1 Stop group, got %d", len(file.Hooks["Stop"]))
	}
	handler := file.Hooks["Stop"][0].Hooks[0]
	if handler.Command != script {
		t.Fatalf("command: got %q want %q", handler.Command, script)
	}
	if handler.Env["AGENT_SESSIONS_AGENT"] != "codex" {
		t.Fatalf("agent env: got %q", handler.Env["AGENT_SESSIONS_AGENT"])
	}
}

func TestMergeCodexHooksPreservesExisting(t *testing.T) {
	existing := []byte(`{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "/bin/other.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "/bin/skynet.sh", "statusMessage": "skynet stop" }
        ]
      }
    ]
  }
}`)
	script := "/home/user/.codex/hooks/agent-sessions-stop.sh"
	merged, err := MergeCodexHooks(existing, codexHooksJSON, script)
	if err != nil {
		t.Fatalf("merge existing: %v", err)
	}

	var file hooksFile
	if err := json.Unmarshal(merged, &file); err != nil {
		t.Fatalf("unmarshal merged: %v", err)
	}
	if len(file.Hooks["UserPromptSubmit"]) != 1 {
		t.Fatalf("UserPromptSubmit group removed — merge must preserve other hooks")
	}
	if len(file.Hooks["Stop"]) != 2 {
		t.Fatalf("expected 2 Stop groups, got %d", len(file.Hooks["Stop"]))
	}

	foundOurs := false
	foundOther := false
	for _, group := range file.Hooks["Stop"] {
		for _, handler := range group.Hooks {
			switch handler.StatusMessage {
			case AgentSessionsHookStatus:
				foundOurs = true
				if handler.Command != script {
					t.Fatalf("our command: got %q", handler.Command)
				}
			case "skynet stop":
				foundOther = true
			}
		}
	}
	if !foundOurs || !foundOther {
		t.Fatalf("missing hooks: ours=%v other=%v", foundOurs, foundOther)
	}
}

func TestMergeCodexHooksUpsertsExistingEntry(t *testing.T) {
	existing := []byte(`{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/old/path.sh",
            "statusMessage": "os-bar agent-sessions notify"
          }
        ]
      }
    ]
  }
}`)
	script := "/new/path.sh"
	merged, err := MergeCodexHooks(existing, codexHooksJSON, script)
	if err != nil {
		t.Fatalf("merge upsert: %v", err)
	}

	var file hooksFile
	if err := json.Unmarshal(merged, &file); err != nil {
		t.Fatalf("unmarshal merged: %v", err)
	}
	if len(file.Hooks["Stop"]) != 1 {
		t.Fatalf("expected 1 Stop group after upsert, got %d", len(file.Hooks["Stop"]))
	}
	if file.Hooks["Stop"][0].Hooks[0].Command != script {
		t.Fatalf("command not updated: got %q", file.Hooks["Stop"][0].Hooks[0].Command)
	}
}

func TestMergeCodexHooksMalformedJSON(t *testing.T) {
	_, err := MergeCodexHooks([]byte("{not json"), codexHooksJSON, "/script.sh")
	if err == nil {
		t.Fatal("expected error for malformed JSON")
	}
}

func TestCodexHooksFixtureUsesScriptPlaceholder(t *testing.T) {
	if !strings.Contains(string(codexHooksJSON), agentSessionsScriptToken) {
		t.Fatalf("codex fixture missing script placeholder %q", agentSessionsScriptToken)
	}
}

func TestHookScriptFixtureHasFallbackChain(t *testing.T) {
	script := string(hookScript)
	for _, marker := range []string{"jq", "python3", "node", "grep -oE"} {
		if !strings.Contains(script, marker) {
			t.Fatalf("hook script missing fallback marker %q", marker)
		}
	}
}

func TestInstallCodexWritesMergedHooks(t *testing.T) {
	dir := t.TempDir()
	home := filepath.Join(dir, "home")
	cwd := filepath.Join(dir, "proj")
	if err := os.MkdirAll(cwd, 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)

	InstallCodex(false, home, cwd, false)

	configPath := filepath.Join(cwd, ".codex", "hooks.json")
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("read hooks.json: %v", err)
	}
	if !strings.Contains(string(data), AgentSessionsHookStatus) {
		t.Fatalf("merged hooks missing our status message: %s", data)
	}

	scriptPath := filepath.Join(cwd, ".codex", "hooks", "agent-sessions-stop.sh")
	info, err := os.Stat(scriptPath)
	if err != nil {
		t.Fatalf("stat hook script: %v", err)
	}
	if info.Mode().Perm()&0111 == 0 {
		t.Fatalf("hook script not executable: %o", info.Mode().Perm())
	}
}

func TestClaudeHookPaths(t *testing.T) {
	home := "/home/user"
	cwd := "/proj"

	globalConfig, globalScript := ClaudeHookPaths(true, home, cwd)
	if globalConfig != filepath.Join(home, ".claude", "settings.json") {
		t.Fatalf("global config path: got %q", globalConfig)
	}
	if globalScript != filepath.Join(home, ".claude", "hooks", "agent-sessions-stop.sh") {
		t.Fatalf("global script path: got %q", globalScript)
	}

	localConfig, localScript := ClaudeHookPaths(false, home, cwd)
	if localConfig != filepath.Join(cwd, ".claude", "settings.json") {
		t.Fatalf("local config path: got %q", localConfig)
	}
	if localScript != filepath.Join(cwd, ".claude", "hooks", "agent-sessions-stop.sh") {
		t.Fatalf("local script path: got %q", localScript)
	}
}

func TestClaudeHooksFixtureUsesScriptPlaceholder(t *testing.T) {
	if !strings.Contains(string(claudeHooksJSON), agentSessionsScriptToken) {
		t.Fatalf("claude fixture missing script placeholder %q", agentSessionsScriptToken)
	}
	if strings.Contains(string(claudeHooksJSON), "\"env\"") {
		t.Fatalf("claude fixture must NOT contain an env field (Claude ignores env); got: %s", claudeHooksJSON)
	}
}

func TestMergeClaudeHooksPreservesTopLevelKeys(t *testing.T) {
	existing := []byte(`{
  "permissions": { "allow": ["Bash(*)"] },
  "env": { "FOO": "bar" },
  "model": "claude-sonnet",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "/bin/other.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "/bin/skynet.sh", "statusMessage": "skynet stop" }
        ]
      }
    ]
  }
}`)
	script := "/home/user/.claude/hooks/agent-sessions-stop.sh"
	merged, err := MergeClaudeHooks(existing, claudeHooksJSON, script)
	if err != nil {
		t.Fatalf("merge existing: %v", err)
	}

	var root map[string]json.RawMessage
	if err := json.Unmarshal(merged, &root); err != nil {
		t.Fatalf("unmarshal merged: %v", err)
	}
	for _, key := range []string{"permissions", "env", "model", "hooks"} {
		if _, ok := root[key]; !ok {
			t.Fatalf("merge removed top-level key %q", key)
		}
	}

	var file hooksFile
	if err := json.Unmarshal(merged, &file); err != nil {
		t.Fatalf("unmarshal merged hooks: %v", err)
	}
	if len(file.Hooks["UserPromptSubmit"]) != 1 {
		t.Fatalf("UserPromptSubmit group removed — merge must preserve foreign hooks")
	}
	if len(file.Hooks["Stop"]) != 2 {
		t.Fatalf("expected 2 Stop groups (foreign + ours), got %d", len(file.Hooks["Stop"]))
	}

	foundOurs := 0
	foundOther := false
	for _, group := range file.Hooks["Stop"] {
		for _, handler := range group.Hooks {
			if handler.StatusMessage == AgentSessionsHookStatus {
				foundOurs++
				cmd := handler.Command
				if !strings.HasPrefix(cmd, "AGENT_SESSIONS_AGENT=claude ") {
					t.Fatalf("our handler command must start with AGENT_SESSIONS_AGENT=claude , got %q", cmd)
				}
				if !strings.HasSuffix(cmd, script) {
					t.Fatalf("our handler command must end with script path %q, got %q", script, cmd)
				}
				if handler.Env != nil {
					t.Fatalf("our claude handler must NOT carry an env field, got %v", handler.Env)
				}
			}
			if handler.StatusMessage == "skynet stop" {
				foundOther = true
			}
		}
	}
	if foundOurs != 1 {
		t.Fatalf("expected exactly 1 our Stop handler, got %d", foundOurs)
	}
	if !foundOther {
		t.Fatalf("foreign skynet Stop handler not preserved")
	}
}

func TestMergeClaudeHooksUpsertsOurs(t *testing.T) {
	existing := []byte(`{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/old/path.sh",
            "statusMessage": "os-bar agent-sessions notify"
          }
        ]
      }
    ]
  }
}`)
	script := "/home/user/.claude/hooks/agent-sessions-stop.sh"
	merged, err := MergeClaudeHooks(existing, claudeHooksJSON, script)
	if err != nil {
		t.Fatalf("merge upsert: %v", err)
	}

	var file hooksFile
	if err := json.Unmarshal(merged, &file); err != nil {
		t.Fatalf("unmarshal merged: %v", err)
	}
	if len(file.Hooks["Stop"]) != 1 {
		t.Fatalf("expected 1 Stop group after upsert, got %d", len(file.Hooks["Stop"]))
	}
	ours := 0
	for _, group := range file.Hooks["Stop"] {
		for _, handler := range group.Hooks {
			if handler.StatusMessage == AgentSessionsHookStatus {
				ours++
			}
		}
	}
	if ours != 1 {
		t.Fatalf("expected exactly 1 our Stop handler after upsert, got %d", ours)
	}
	cmd := file.Hooks["Stop"][0].Hooks[0].Command
	if !strings.Contains(cmd, "AGENT_SESSIONS_AGENT=claude") {
		t.Fatalf("upserted command must contain AGENT_SESSIONS_AGENT=claude, got %q", cmd)
	}
	if !strings.Contains(cmd, script) {
		t.Fatalf("upserted command must contain new script path %q, got %q", script, cmd)
	}
	if strings.Contains(cmd, "/old/path.sh") {
		t.Fatalf("stale command path not updated: %q", cmd)
	}
}

func TestMergeClaudeHooksEmpty(t *testing.T) {
	script := "/home/user/.claude/hooks/agent-sessions-stop.sh"
	merged, err := MergeClaudeHooks(nil, claudeHooksJSON, script)
	if err != nil {
		t.Fatalf("merge empty: %v", err)
	}

	var file hooksFile
	if err := json.Unmarshal(merged, &file); err != nil {
		t.Fatalf("unmarshal merged: %v", err)
	}
	if len(file.Hooks["Stop"]) != 1 {
		t.Fatalf("expected 1 Stop group, got %d", len(file.Hooks["Stop"]))
	}
	handler := file.Hooks["Stop"][0].Hooks[0]
	cmd := handler.Command
	if !strings.Contains(cmd, "AGENT_SESSIONS_AGENT=claude") {
		t.Fatalf("command must contain AGENT_SESSIONS_AGENT=claude, got %q", cmd)
	}
	if !strings.Contains(cmd, script) {
		t.Fatalf("command must contain script path %q, got %q", script, cmd)
	}
}

func TestMergeClaudeHooksMalformedJSON(t *testing.T) {
	_, err := MergeClaudeHooks([]byte("{not json"), claudeHooksJSON, "/script.sh")
	if err == nil {
		t.Fatal("expected error for malformed JSON")
	}
}

func TestInstallClaudeWritesMergedSettings(t *testing.T) {
	dir := t.TempDir()
	home := filepath.Join(dir, "home")
	cwd := filepath.Join(dir, "proj")
	if err := os.MkdirAll(cwd, 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)

	InstallClaude(false, home, cwd, false)

	configPath := filepath.Join(cwd, ".claude", "settings.json")
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("read settings.json: %v", err)
	}
	if !strings.Contains(string(data), AgentSessionsHookStatus) {
		t.Fatalf("merged settings missing our status message: %s", data)
	}
	if !strings.Contains(string(data), "AGENT_SESSIONS_AGENT=claude") {
		t.Fatalf("merged settings missing AGENT_SESSIONS_AGENT=claude command prefix: %s", data)
	}

	scriptPath := filepath.Join(cwd, ".claude", "hooks", "agent-sessions-stop.sh")
	info, err := os.Stat(scriptPath)
	if err != nil {
		t.Fatalf("stat hook script: %v", err)
	}
	if info.Mode().Perm()&0111 == 0 {
		t.Fatalf("hook script not executable: %o", info.Mode().Perm())
	}
}