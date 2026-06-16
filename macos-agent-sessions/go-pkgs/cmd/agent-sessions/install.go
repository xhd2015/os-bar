package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	agentSessionsHookStatus  = "os-bar agent-sessions notify"
	agentSessionsScriptToken = "__AGENT_SESSIONS_SCRIPT__"
)

type hooksFile struct {
	Hooks map[string][]hookMatcherGroup `json:"hooks"`
}

type hookMatcherGroup struct {
	Matcher string        `json:"matcher,omitempty"`
	Hooks   []hookHandler `json:"hooks"`
}

type hookHandler struct {
	Type          string            `json:"type"`
	Command       string            `json:"command"`
	Timeout       int               `json:"timeout,omitempty"`
	StatusMessage string            `json:"statusMessage,omitempty"`
	Env           map[string]string `json:"env,omitempty"`
}

func grokHookPaths(global bool, homeDir, cwd string) (configPath, scriptPath string) {
	var base string
	if global {
		base = filepath.Join(homeDir, ".grok", "hooks")
	} else {
		base = filepath.Join(cwd, ".grok", "hooks")
	}
	return filepath.Join(base, "agent-sessions.json"), filepath.Join(base, "bin", "agent-sessions-stop.sh")
}

func codexHookPaths(global bool, homeDir, cwd string) (configPath, scriptPath string) {
	if global {
		return filepath.Join(homeDir, ".codex", "hooks.json"), filepath.Join(homeDir, ".codex", "hooks", "agent-sessions-stop.sh")
	}
	return filepath.Join(cwd, ".codex", "hooks.json"), filepath.Join(cwd, ".codex", "hooks", "agent-sessions-stop.sh")
}

func parseHooksFile(data []byte, label string) (hooksFile, error) {
	var file hooksFile
	if len(bytes.TrimSpace(data)) == 0 {
		return hooksFile{Hooks: make(map[string][]hookMatcherGroup)}, nil
	}
	if err := json.Unmarshal(data, &file); err != nil {
		return hooksFile{}, fmt.Errorf("parse %s: %w", label, err)
	}
	if file.Hooks == nil {
		file.Hooks = make(map[string][]hookMatcherGroup)
	}
	return file, nil
}

func codexHooksFixture(scriptPath string, fixtureTemplate []byte) (hooksFile, error) {
	fixture := bytes.ReplaceAll(fixtureTemplate, []byte(agentSessionsScriptToken), []byte(scriptPath))
	return parseHooksFile(fixture, "codex hooks fixture")
}

// mergeCodexHooks merges our fixture hooks into an existing hooks.json.
// Existing hooks from other tools are preserved; only entries with
// statusMessage "os-bar agent-sessions notify" are upserted.
func mergeCodexHooks(existing, fixtureTemplate []byte, scriptPath string) ([]byte, error) {
	existingFile, err := parseHooksFile(existing, "hooks.json")
	if err != nil {
		return nil, err
	}

	fixtureFile, err := codexHooksFixture(scriptPath, fixtureTemplate)
	if err != nil {
		return nil, err
	}

	for event, fixtureGroups := range fixtureFile.Hooks {
		for _, fixtureGroup := range fixtureGroups {
			for _, fixtureHandler := range fixtureGroup.Hooks {
				if fixtureHandler.StatusMessage != agentSessionsHookStatus {
					continue
				}
				upsertHookHandler(&existingFile, event, fixtureHandler)
			}
		}
	}

	out, err := json.MarshalIndent(existingFile, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}

func upsertHookHandler(file *hooksFile, event string, handler hookHandler) {
	groups := file.Hooks[event]
	for i, group := range groups {
		for j, existing := range group.Hooks {
			if existing.StatusMessage == agentSessionsHookStatus {
				groups[i].Hooks[j] = handler
				file.Hooks[event] = groups
				return
			}
		}
	}
	file.Hooks[event] = append(groups, hookMatcherGroup{Hooks: []hookHandler{handler}})
}

func installGrok(global bool, homeDir, cwd string, dryRun bool) {
	configPath, scriptPath := grokHookPaths(global, homeDir, cwd)
	checkAndWrite("grok hook script", scriptPath, hookScript, dryRun)
	checkAndWrite("grok hooks", configPath, grokHooksJSON, dryRun)
}

func installCodex(global bool, homeDir, cwd string, dryRun bool) {
	configPath, scriptPath := codexHookPaths(global, homeDir, cwd)
	checkAndWrite("codex hook script", scriptPath, hookScript, dryRun)

	existing, err := os.ReadFile(configPath)
	if err != nil && !os.IsNotExist(err) {
		fmt.Printf("  codex hooks: error reading %s: %v\n", configPath, err)
		return
	}

	merged, err := mergeCodexHooks(existing, codexHooksJSON, scriptPath)
	if err != nil {
		fmt.Printf("  codex hooks: error merging %s: %v\n", configPath, err)
		return
	}

	existingNorm := strings.ReplaceAll(string(existing), "\r\n", "\n")
	mergedNorm := strings.ReplaceAll(string(merged), "\r\n", "\n")
	if existingNorm == mergedNorm {
		fmt.Printf("  codex hooks: up to date → %s\n", configPath)
		return
	}

	if len(existing) == 0 {
		fmt.Printf("  codex hooks: install → %s\n", configPath)
	} else {
		fmt.Printf("  codex hooks: update → %s\n", configPath)
	}
	if dryRun {
		return
	}

	if err := os.MkdirAll(filepath.Dir(configPath), 0755); err != nil {
		fmt.Printf("    error: cannot create directory %s: %v\n", filepath.Dir(configPath), err)
		return
	}
	if err := os.WriteFile(configPath, merged, 0644); err != nil {
		fmt.Printf("    error: cannot write %s: %v\n", configPath, err)
		return
	}
	fmt.Printf("    written\n")
}