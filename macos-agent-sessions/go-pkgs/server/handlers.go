package server

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/xhd2015/os-bar/macos-agent-sessions/go-pkgs/integrations"
)

type daemon struct {
	port     int
	stateDir string
	store    *store
}

func (d *daemon) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (d *daemon) handleList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, d.store.listEvents())
}

func (d *daemon) handleInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"storage_path": d.stateDir,
		"port":         d.port,
		"event_count":  d.store.eventCount(),
	})
}

func (d *daemon) handleLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, d.store.listLogs())
}

func (d *daemon) handleNotify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}

	var payload map[string]json.RawMessage
	if err := json.Unmarshal(body, &payload); err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}

	var dir string
	if raw, ok := payload["dir"]; ok {
		if err := json.Unmarshal(raw, &dir); err != nil || dir == "" {
			writeJSONError(w, http.StatusBadRequest, "missing or empty dir")
			return
		}
	} else {
		writeJSONError(w, http.StatusBadRequest, "missing or empty dir")
		return
	}

	var source string
	if raw, ok := payload["source"]; ok {
		_ = json.Unmarshal(raw, &source)
	}

	var event string
	if raw, ok := payload["event"]; ok {
		_ = json.Unmarshal(raw, &event)
	}

	entry := NotifyLogEntry{
		Source:    source,
		Timestamp: formatTimestamp(time.Now()),
		Dir:       dir,
		Event:     event,
	}

	if raw, ok := payload["pi"]; ok {
		var pi PiLogDetails
		if json.Unmarshal(raw, &pi) == nil {
			entry.Pi = &pi
		}
	}
	if raw, ok := payload["opencode"]; ok {
		var oc OpencodeLogDetails
		if json.Unmarshal(raw, &oc) == nil {
			entry.Opencode = &oc
		}
	}
	if raw, ok := payload["command"]; ok {
		var cmd CommandLogDetails
		if json.Unmarshal(raw, &cmd) == nil {
			entry.Command = &cmd
		}
	}

	d.store.appendLog(entry)

	if source == "notify" {
		d.store.addEvent(dir)
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (d *daemon) handleEvents(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodDelete:
		d.handleDeleteEvents(w, r)
	default:
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (d *daemon) handleDeleteEvents(w http.ResponseWriter, r *http.Request) {
	dir := r.URL.Query().Get("dir")
	if dir == "" {
		writeJSONError(w, http.StatusBadRequest, "missing dir parameter")
		return
	}
	if decoded, err := url.QueryUnescape(dir); err == nil {
		dir = decoded
	}

	removed := d.store.removeEvents(dir)
	if removed == 0 {
		writeJSONError(w, http.StatusNotFound, "no events found for dir")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"ok": true, "removed": removed})
}

func (d *daemon) handleConsume(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}

	var req struct {
		Dir string `json:"dir"`
	}
	if err := json.Unmarshal(body, &req); err != nil || req.Dir == "" {
		writeJSONError(w, http.StatusBadRequest, "missing or empty dir")
		return
	}

	d.store.markConsumed(req.Dir)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (d *daemon) handleConsumeAll(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	d.store.markAllConsumed()
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (d *daemon) handleIntegrations(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	global := r.URL.Query().Get("global") == "1" || strings.EqualFold(r.URL.Query().Get("global"), "true")
	homeDir, _ := os.UserHomeDir()
	cwd, _ := os.Getwd()
	entries := integrations.List(global, homeDir, cwd)
	writeJSON(w, http.StatusOK, integrations.IntegrationsResponse{Integrations: entries})
}

func (d *daemon) handleConfig(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		d.handleConfigGet(w, r)
	case http.MethodPost:
		d.handleConfigSet(w, r)
	default:
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (d *daemon) handleConfigGet(w http.ResponseWriter, r *http.Request) {
	cfg, err := d.loadConfig()
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, cfg)
}

func (d *daemon) handleConfigSet(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}
	var req struct {
		OpenMethod string `json:"open_method"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if !isValidOpenMethod(req.OpenMethod) {
		writeJSONError(w, http.StatusBadRequest, "invalid open_method; must be 'vscode' or 'iterm2'")
		return
	}
	if err := d.saveConfig(&Config{OpenMethod: req.OpenMethod}); err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (d *daemon) handleOpenDir(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}

	var req struct {
		Dir        string `json:"dir"`
		OpenMethod string `json:"open_method"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Dir == "" {
		writeJSONError(w, http.StatusBadRequest, "missing dir")
		return
	}

	method := req.OpenMethod
	if method == "" {
		cfg, cfgErr := d.loadConfig()
		if cfgErr != nil {
			writeJSONError(w, http.StatusInternalServerError, cfgErr.Error())
			return
		}
		method = cfg.OpenMethod
	}

	if !isValidOpenMethod(method) {
		writeJSONError(w, http.StatusBadRequest, "invalid open_method")
		return
	}

	switch method {
	case openMethodVSCode:
		if err := openInVSCode(req.Dir); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
	case openMethodIterm2:
		if err := openInIterm2(req.Dir); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"ok":               true,
		"open_method_used": method,
	})
}

func (d *daemon) handleIntegrationsInstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid json")
		return
	}

	var req struct {
		Target string `json:"target"`
		Global bool   `json:"global"`
	}
	if err := json.Unmarshal(body, &req); err != nil || req.Target == "" {
		writeJSONError(w, http.StatusBadRequest, "missing target")
		return
	}

	homeDir, _ := os.UserHomeDir()
	cwd, _ := os.Getwd()
	if err := integrations.Install(req.Target, req.Global, homeDir, cwd); err != nil {
		writeJSONError(w, http.StatusBadRequest, err.Error())
		return
	}

	entries := integrations.List(req.Global, homeDir, cwd)
	writeJSON(w, http.StatusOK, integrations.IntegrationsResponse{Integrations: entries})
}

func (d *daemon) handleNotFound(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.URL.Path, "/api/") {
		writeJSONError(w, http.StatusNotFound, "not found")
		return
	}
	http.NotFound(w, r)
}

func writeJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeJSONError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}