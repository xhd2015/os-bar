package main

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

	globalConfig, globalScript := grokHookPaths(true, home, cwd)
	if globalConfig != filepath.Join(home, ".grok", "hooks", "agent-sessions.json") {
		t.Fatalf("global config path: got %q", globalConfig)
	}
	if globalScript != filepath.Join(home, ".grok", "hooks", "bin", "agent-sessions-stop.sh") {
		t.Fatalf("global script path: got %q", globalScript)
	}

	localConfig, localScript := grokHookPaths(false, home, cwd)
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

	globalConfig, globalScript := codexHookPaths(true, home, cwd)
	if globalConfig != filepath.Join(home, ".codex", "hooks.json") {
		t.Fatalf("global config path: got %q", globalConfig)
	}
	if globalScript != filepath.Join(home, ".codex", "hooks", "agent-sessions-stop.sh") {
		t.Fatalf("global script path: got %q", globalScript)
	}

	localConfig, localScript := codexHookPaths(false, home, cwd)
	if localConfig != filepath.Join(cwd, ".codex", "hooks.json") {
		t.Fatalf("local config path: got %q", localConfig)
	}
	if localScript != filepath.Join(cwd, ".codex", "hooks", "agent-sessions-stop.sh") {
		t.Fatalf("local script path: got %q", localScript)
	}
}

func TestMergeCodexHooksEmpty(t *testing.T) {
	script := "/home/user/.codex/hooks/agent-sessions-stop.sh"
	merged, err := mergeCodexHooks(nil, codexHooksJSON, script)
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
	merged, err := mergeCodexHooks(existing, codexHooksJSON, script)
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
			case agentSessionsHookStatus:
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
	merged, err := mergeCodexHooks(existing, codexHooksJSON, script)
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
	_, err := mergeCodexHooks([]byte("{not json"), codexHooksJSON, "/script.sh")
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

	installCodex(false, home, cwd, false)

	configPath := filepath.Join(cwd, ".codex", "hooks.json")
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("read hooks.json: %v", err)
	}
	if !strings.Contains(string(data), agentSessionsHookStatus) {
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