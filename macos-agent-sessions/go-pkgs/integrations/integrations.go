package integrations

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

//go:embed scripts/pi-agent-sessions-hook.ts
var piExtension []byte

//go:embed scripts/opencode-agent-sessions-plugin.ts
var opencodePlugin []byte

//go:embed scripts/agent-sessions-stop.sh
var hookScript []byte

//go:embed scripts/grok-agent-sessions-hooks.json
var grokHooksJSON []byte

//go:embed scripts/codex-agent-sessions-hooks.json
var codexHooksJSON []byte

const (
	AgentSessionsHookStatus  = "os-bar agent-sessions notify"
	agentSessionsScriptToken = "__AGENT_SESSIONS_SCRIPT__"
)

// IntegrationEntry describes install status for one integration target.
type IntegrationEntry struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Path   string `json:"path"`
	Scope  string `json:"scope"`
}

// IntegrationsResponse is the JSON envelope for integrations list endpoints.
type IntegrationsResponse struct {
	Integrations []IntegrationEntry `json:"integrations"`
}

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

// List returns install status for grok, opencode, pi, and codex.
func List(global bool, homeDir, cwd string) []IntegrationEntry {
	scope := "local"
	if global {
		scope = "global"
	}
	return []IntegrationEntry{
		grokIntegrationStatus(global, homeDir, cwd, scope),
		opencodeIntegrationStatus(global, homeDir, cwd, scope),
		piIntegrationStatus(global, homeDir, cwd, scope),
		codexIntegrationStatus(global, homeDir, cwd, scope),
	}
}

// Install writes integration files for the given target without CLI output.
func Install(target string, global bool, homeDir, cwd string) error {
	switch target {
	case "grok":
		InstallGrok(global, homeDir, cwd, false)
	case "opencode":
		var targetPath string
		if global {
			targetPath = filepath.Join(homeDir, ".config", "opencode", "plugins", "agent-sessions.ts")
		} else {
			targetPath = filepath.Join(cwd, ".opencode", "plugins", "agent-sessions.ts")
		}
		CheckAndWrite("opencode plugin", targetPath, opencodePlugin, false)
	case "pi":
		var targetPath string
		if global {
			targetPath = filepath.Join(homeDir, ".pi", "agent", "extensions", "agent-sessions-hook.ts")
		} else {
			targetPath = filepath.Join(cwd, ".pi", "extensions", "agent-sessions-hook.ts")
		}
		CheckAndWrite("pi extension", targetPath, piExtension, false)
	case "codex":
		InstallCodex(global, homeDir, cwd, false)
	default:
		return fmt.Errorf("unknown target %q", target)
	}
	return nil
}

func contentMatches(existing, expected []byte) bool {
	existingNorm := strings.ReplaceAll(string(existing), "\r\n", "\n")
	expectedNorm := strings.ReplaceAll(string(expected), "\r\n", "\n")
	return existingNorm == expectedNorm
}

func singleFileStatus(path string, expected []byte) string {
	existing, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return "missing"
		}
		return "missing"
	}
	if contentMatches(existing, expected) {
		return "up_to_date"
	}
	return "outdated"
}

func grokIntegrationStatus(global bool, homeDir, cwd, scope string) IntegrationEntry {
	configPath, scriptPath := GrokHookPaths(global, homeDir, cwd)
	status := "missing"

	configData, err := os.ReadFile(configPath)
	if err != nil {
		if !os.IsNotExist(err) {
			status = "missing"
		}
	} else {
		configOK := contentMatches(configData, grokHooksJSON)
		scriptData, scriptErr := os.ReadFile(scriptPath)
		scriptOK := scriptErr == nil && contentMatches(scriptData, hookScript)
		switch {
		case configOK && scriptOK:
			status = "up_to_date"
		default:
			status = "outdated"
		}
	}

	return IntegrationEntry{ID: "grok", Status: status, Path: configPath, Scope: scope}
}

func opencodeIntegrationStatus(global bool, homeDir, cwd, scope string) IntegrationEntry {
	var targetPath string
	if global {
		targetPath = filepath.Join(homeDir, ".config", "opencode", "plugins", "agent-sessions.ts")
	} else {
		targetPath = filepath.Join(cwd, ".opencode", "plugins", "agent-sessions.ts")
	}
	return IntegrationEntry{
		ID:     "opencode",
		Status: singleFileStatus(targetPath, opencodePlugin),
		Path:   targetPath,
		Scope:  scope,
	}
}

func piIntegrationStatus(global bool, homeDir, cwd, scope string) IntegrationEntry {
	var targetPath string
	if global {
		targetPath = filepath.Join(homeDir, ".pi", "agent", "extensions", "agent-sessions-hook.ts")
	} else {
		targetPath = filepath.Join(cwd, ".pi", "extensions", "agent-sessions-hook.ts")
	}
	return IntegrationEntry{
		ID:     "pi",
		Status: singleFileStatus(targetPath, piExtension),
		Path:   targetPath,
		Scope:  scope,
	}
}

func codexIntegrationStatus(global bool, homeDir, cwd, scope string) IntegrationEntry {
	configPath, scriptPath := CodexHookPaths(global, homeDir, cwd)
	status := "missing"

	existing, err := os.ReadFile(configPath)
	if err != nil && !os.IsNotExist(err) {
		return IntegrationEntry{ID: "codex", Status: "missing", Path: configPath, Scope: scope}
	}

	if os.IsNotExist(err) {
		if _, scriptErr := os.ReadFile(scriptPath); scriptErr != nil && os.IsNotExist(scriptErr) {
			return IntegrationEntry{ID: "codex", Status: "missing", Path: configPath, Scope: scope}
		}
		status = "outdated"
	} else {
		merged, mergeErr := MergeCodexHooks(existing, codexHooksJSON, scriptPath)
		if mergeErr != nil {
			status = "outdated"
		} else if codexHooksCurrent(existing, merged, scriptPath) {
			status = "up_to_date"
		} else {
			status = "outdated"
		}
	}

	return IntegrationEntry{ID: "codex", Status: status, Path: configPath, Scope: scope}
}

func codexHooksCurrent(existing, merged []byte, scriptPath string) bool {
	scriptData, scriptErr := os.ReadFile(scriptPath)
	if scriptErr != nil || !contentMatches(scriptData, hookScript) {
		return false
	}
	if contentMatches(existing, merged) {
		return true
	}
	existingFile, err := parseHooksFile(existing, "hooks.json")
	if err != nil {
		return false
	}
	mergedFile, err := parseHooksFile(merged, "merged hooks")
	if err != nil {
		return false
	}
	return codexHooksSemanticallyEqual(existingFile, mergedFile, scriptPath)
}

func codexHooksSemanticallyEqual(existing, desired hooksFile, scriptPath string) bool {
	desiredHandler, desiredOK := findAgentSessionsHook(desired)
	existingHandler, existingOK := findAgentSessionsHook(existing)
	if !desiredOK || !existingOK {
		return false
	}
	if existingHandler.Command != scriptPath || desiredHandler.Command != scriptPath {
		return false
	}
	return existingHandler.Type == desiredHandler.Type &&
		existingHandler.Timeout == desiredHandler.Timeout &&
		existingHandler.StatusMessage == desiredHandler.StatusMessage &&
		envMapsEqual(existingHandler.Env, desiredHandler.Env)
}

func findAgentSessionsHook(file hooksFile) (hookHandler, bool) {
	for _, groups := range file.Hooks {
		for _, group := range groups {
			for _, handler := range group.Hooks {
				if handler.StatusMessage == AgentSessionsHookStatus {
					return handler, true
				}
			}
		}
	}
	return hookHandler{}, false
}

func envMapsEqual(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for key, val := range a {
		if b[key] != val {
			return false
		}
	}
	return true
}

// GrokHookPaths returns config and script paths for grok hooks.
func GrokHookPaths(global bool, homeDir, cwd string) (configPath, scriptPath string) {
	var base string
	if global {
		base = filepath.Join(homeDir, ".grok", "hooks")
	} else {
		base = filepath.Join(cwd, ".grok", "hooks")
	}
	return filepath.Join(base, "agent-sessions.json"), filepath.Join(base, "bin", "agent-sessions-stop.sh")
}

// CodexHookPaths returns config and script paths for codex hooks.
func CodexHookPaths(global bool, homeDir, cwd string) (configPath, scriptPath string) {
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

// MergeCodexHooks merges our fixture hooks into an existing hooks.json.
func MergeCodexHooks(existing, fixtureTemplate []byte, scriptPath string) ([]byte, error) {
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
				if fixtureHandler.StatusMessage != AgentSessionsHookStatus {
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
			if existing.StatusMessage == AgentSessionsHookStatus {
				groups[i].Hooks[j] = handler
				file.Hooks[event] = groups
				return
			}
		}
	}
	file.Hooks[event] = append(groups, hookMatcherGroup{Hooks: []hookHandler{handler}})
}

// InstallGrok installs grok hook config and script.
func InstallGrok(global bool, homeDir, cwd string, dryRun bool) {
	configPath, scriptPath := GrokHookPaths(global, homeDir, cwd)
	CheckAndWrite("grok hook script", scriptPath, hookScript, dryRun)
	CheckAndWrite("grok hooks", configPath, grokHooksJSON, dryRun)
}

// InstallCodex installs codex hook config and script.
func InstallCodex(global bool, homeDir, cwd string, dryRun bool) {
	configPath, scriptPath := CodexHookPaths(global, homeDir, cwd)
	CheckAndWrite("codex hook script", scriptPath, hookScript, dryRun)

	existing, err := os.ReadFile(configPath)
	if err != nil && !os.IsNotExist(err) {
		fmt.Printf("  codex hooks: error reading %s: %v\n", configPath, err)
		return
	}

	merged, err := MergeCodexHooks(existing, codexHooksJSON, scriptPath)
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

// CheckAndWrite installs or updates a single integration file with CLI output.
func CheckAndWrite(label string, targetPath string, script []byte, dryRun bool) (written bool) {
	dir := filepath.Dir(targetPath)

	perm := os.FileMode(0644)
	if strings.HasSuffix(targetPath, ".sh") {
		perm = 0755
	}

	existing, err := os.ReadFile(targetPath)
	if err != nil {
		if !os.IsNotExist(err) {
			fmt.Printf("  %s: error reading %s: %v\n", label, targetPath, err)
			return
		}
		fmt.Printf("  %s: install → %s\n", label, targetPath)
		if !dryRun {
			if err := os.MkdirAll(dir, 0755); err != nil {
				fmt.Printf("    error: cannot create directory %s: %v\n", dir, err)
				return
			}
			if err := os.WriteFile(targetPath, script, perm); err != nil {
				fmt.Printf("    error: cannot write %s: %v\n", targetPath, err)
				return
			}
			fmt.Printf("    written\n")
			written = true
		}
		return
	}

	existingNorm := strings.ReplaceAll(string(existing), "\r\n", "\n")
	scriptNorm := strings.ReplaceAll(string(script), "\r\n", "\n")

	if existingNorm == scriptNorm {
		fmt.Printf("  %s: up to date → %s\n", label, targetPath)
		return
	}

	fmt.Printf("  %s: update → %s\n", label, targetPath)
	if dryRun {
		if len(existing) != len(script) {
			fmt.Printf("    (size differs: installed %d bytes, bundled %d bytes)\n", len(existing), len(script))
		}
		return
	}

	if err := os.WriteFile(targetPath, script, perm); err != nil {
		fmt.Printf("    error: cannot write %s: %v\n", targetPath, err)
		return
	}
	fmt.Printf("    updated\n")
	written = true
	return
}

// CodexHooksJSON returns the embedded codex hooks fixture template.
func CodexHooksJSON() []byte {
	return codexHooksJSON
}

// HookScript returns the embedded hook shell script.
func HookScript() []byte {
	return hookScript
}

// PiExtension returns the embedded pi extension script.
func PiExtension() []byte {
	return piExtension
}

// OpencodePlugin returns the embedded opencode plugin script.
func OpencodePlugin() []byte {
	return opencodePlugin
}