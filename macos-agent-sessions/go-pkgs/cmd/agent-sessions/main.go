package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httputil"
	"os"
	"path/filepath"
	"strings"
	"time"

	lessflags "github.com/xhd2015/less-flags"
	"github.com/xhd2015/os-bar/macos-agent-sessions/go-pkgs/server"
)

const (
	defaultPort = 38271
	defaultHost = "localhost"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	subcommand := os.Args[1]
	args := os.Args[2:]

	switch subcommand {
	case "notify":
		cmdNotify(args)
	case "list":
		cmdList(args)
	case "status":
		cmdStatus(args)
	case "config-location":
		cmdConfigLocation(args)
	case "remove":
		cmdRemove(args)
	case "logs":
		cmdLogs(args)
	case "install":
		cmdInstall(args)
	case "integrations":
		cmdIntegrations(args)
	case "watch":
		cmdWatch(args)
	case "serve":
		if err := server.RunServe(args); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
	case "-h", "--help":
		printUsage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand: %s\n", subcommand)
		printUsage()
		os.Exit(1)
	}
}

func serverURL(path string) string {
	return fmt.Sprintf("http://%s:%d%s", defaultHost, defaultPort, path)
}

func printUsage() {
	fmt.Print(`Usage: agent-sessions <command> [flags]

Commands:
  notify           Send a session notification event
  list             List recent sessions
  status           Check if the agent sessions server is running
  config-location  Show where session data files are stored
  install          Install or update integration scripts
  integrations     Report integration install status
  logs             Show notification log entries (debugging)
  remove           Remove session events for a directory
  watch            Watch a directory and notify on file changes
  serve            Start the HTTP daemon server

Run 'agent-sessions <command> --help' for more details.
`)
}

// --- notify subcommand ---

func cmdNotify(args []string) {
	var dir string
	var event string
	var payload string
	var debugHTTP bool

	helpText := `Usage: agent-sessions notify --event <event> [flags]

Send a session notification event to the os-bar agent sessions server.

Flags:
  --event EVENT    event to send (e.g., session.finished)
  --dir DIR        working directory (default: current working directory)
  --payload JSON   raw JSON body (overrides --event and --dir)
  --debug-http     print underlying HTTP request and response
  -h, --help       show help
`

	_, err := lessflags.String("--event", &event).
		String("--dir", &dir).
		String("--payload", &payload).
		Bool("--debug-http", &debugHTTP).
		Help("-h,--help", helpText).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if payload == "" && event == "" {
		fmt.Fprintf(os.Stderr, "error: --event is required (or use --payload)\n")
		os.Exit(1)
	}

	var bodyBytes []byte
	if payload != "" {
		bodyBytes = []byte(payload)
	} else {
		if dir == "" {
			cwd, err := os.Getwd()
			if err != nil {
				fmt.Fprintf(os.Stderr, "error: cannot get current working directory: %v\n", err)
				os.Exit(1)
			}
			dir = cwd
		}
		absDir, err := filepath.Abs(dir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: cannot resolve directory %q: %v\n", dir, err)
			os.Exit(1)
		}
		body := map[string]string{"dir": absDir, "event": event}
		bodyBytes, err = json.Marshal(body)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to marshal JSON: %v\n", err)
			os.Exit(1)
		}
	}

	url := serverURL("/api/notify")
	req, err := http.NewRequest("POST", url, bytes.NewReader(bodyBytes))
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to create request: %v\n", err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")

	if debugHTTP {
		dump, err := httputil.DumpRequestOut(req, true)
		if err == nil {
			fmt.Fprintf(os.Stderr, "--- HTTP Request ---\n%s\n", dump)
		}
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to connect to server at %s: %v\n", url, err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if debugHTTP {
		dump, err := httputil.DumpResponse(resp, true)
		if err == nil {
			fmt.Fprintf(os.Stderr, "--- HTTP Response ---\n%s\n", dump)
		}
	}

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(os.Stderr, "error: server returned status %d: %s\n", resp.StatusCode, string(respBody))
		os.Exit(1)
	}

	fmt.Println("notification sent")
}

// --- list subcommand ---

type sessionEvent struct {
	ID        string `json:"id"`
	Dir       string `json:"dir"`
	Timestamp string `json:"timestamp"`
	Consumed  bool   `json:"consumed"`
}

func cmdList(args []string) {
	limit := 20

	helpText := `Usage: agent-sessions list [flags]

List recent sessions from the os-bar agent sessions server.

Flags:
  --limit N       maximum number of sessions to show (default: 20, max: 100)
  -h, --help      show help
`

	_, err := lessflags.Int("--limit", &limit).
		Help("-h,--help", helpText).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if limit < 1 {
		limit = 1
	}
	if limit > 100 {
		limit = 100
	}

	url := serverURL("/api/list")
	resp, err := http.Get(url)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to connect to server at %s: %v\n", url, err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(os.Stderr, "error: server returned status %d: %s\n", resp.StatusCode, string(respBody))
		os.Exit(1)
	}

	var events []sessionEvent
	if err := json.NewDecoder(resp.Body).Decode(&events); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to parse server response: %v\n", err)
		os.Exit(1)
	}

	// Limit results
	if len(events) > limit {
		events = events[:limit]
	}

	if len(events) == 0 {
		fmt.Println("No sessions")
		return
	}

	// Print in macOS dropdown-like format:
	//   ● basename — 3m ago   (unconsumed)
	//     /full/path
	for _, ev := range events {
		indicator := " "
		if !ev.Consumed {
			indicator = "●"
		}
		basename := filepath.Base(ev.Dir)
		relTime := formatRelativeTimeISO(ev.Timestamp)
		fmt.Printf("%s %s — %s\n    └── %s\n", indicator, basename, relTime, ev.Dir)
	}
}

// formatRelativeTimeISO parses an ISO 8601 timestamp and returns a relative time
// string matching the macOS app's format ("<1m ago", "3m ago", "2h ago", "5d ago").
func formatRelativeTimeISO(isoTimestamp string) string {
	t, err := time.Parse(time.RFC3339, isoTimestamp)
	if err != nil {
		// Also try ISO 8601 without timezone offset (e.g., "2024-01-01T12:00:00Z")
		t, err = time.Parse("2006-01-02T15:04:05Z", isoTimestamp)
		if err != nil {
			return "?"
		}
	}
	return formatRelativeTime(t)
}

func formatRelativeTime(t time.Time) string {
	diff := time.Since(t)
	if diff < 0 {
		diff = 0
	}
	switch {
	case diff < time.Minute:
		return "<1m ago"
	case diff < time.Hour:
		return fmt.Sprintf("%dm ago", int(diff.Minutes()))
	case diff < 24*time.Hour:
		return fmt.Sprintf("%dh ago", int(diff.Hours()))
	default:
		return fmt.Sprintf("%dd ago", int(diff.Hours()/24))
	}
}

// --- status subcommand ---

func cmdStatus(args []string) {
	helpText := `Usage: agent-sessions status [flags]

Check if the os-bar agent sessions server is running.

Flags:
  -h, --help  show help
`

	_, err := lessflags.Help("-h,--help", helpText).Parse(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	url := serverURL("/api/list")
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		fmt.Printf("Server is not running (port %d): %v\n", defaultPort, err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		var events []sessionEvent
		if err := json.NewDecoder(resp.Body).Decode(&events); err == nil {
			unconsumed := 0
			for _, ev := range events {
				if !ev.Consumed {
					unconsumed++
				}
			}
			fmt.Printf("Server is running on port %d\n", defaultPort)
			fmt.Printf("Sessions: %d total, %d unconsumed\n", len(events), unconsumed)
			return
		}
	}
	fmt.Printf("Server is running on port %d (status %d)\n", defaultPort, resp.StatusCode)
}

// --- config-location subcommand ---

func cmdConfigLocation(args []string) {
	helpText := `Usage: agent-sessions config-location [flags]

Query the server for the location of session data files.

Flags:
  -h, --help  show help
`

	_, err := lessflags.Help("-h,--help", helpText).Parse(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	url := serverURL("/api/info")
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: server not reachable (port %d): %v\n", defaultPort, err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(os.Stderr, "error: server returned status %d: %s\n", resp.StatusCode, string(respBody))
		os.Exit(1)
	}

	// Just dump the response
	respBody, _ := io.ReadAll(resp.Body)
	fmt.Print(string(respBody))
}

// --- remove subcommand ---

func cmdRemove(args []string) {
	var dir string

	helpText := `Usage: agent-sessions remove <dir> [flags]

Remove session events for the given directory from the server.

Flags:
  --dir DIR   target directory (default: current working directory)
  -h, --help  show help
`

	_, err := lessflags.String("--dir", &dir).
		Help("-h,--help", helpText).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if dir == "" {
		cwd, err := os.Getwd()
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: cannot get current working directory: %v\n", err)
			os.Exit(1)
		}
		dir = cwd
	}

	absDir, err := filepath.Abs(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot resolve directory %q: %v\n", dir, err)
		os.Exit(1)
	}

	url := fmt.Sprintf("%s?dir=%s", serverURL("/api/events"), absDir)
	req, err := http.NewRequest("DELETE", url, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to create request: %v\n", err)
		os.Exit(1)
	}

	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: server not reachable (port %d): %v\n", defaultPort, err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		fmt.Fprintf(os.Stderr, "error: no events found for %s\n", absDir)
		os.Exit(1)
	}
	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(os.Stderr, "error: server returned status %d: %s\n", resp.StatusCode, string(respBody))
		os.Exit(1)
	}

	respBody, _ := io.ReadAll(resp.Body)
	fmt.Print(string(respBody))
}

// --- logs subcommand ---

type notifyLogEntry struct {
	Source    string              `json:"source"`
	Timestamp string              `json:"timestamp"`
	Dir       string              `json:"dir"`
	Event     string              `json:"event,omitempty"`
	Pi        *piLogDetails       `json:"pi,omitempty"`
	Opencode  *opencodeLogDetails `json:"opencode,omitempty"`
	Command   *commandLogDetails  `json:"command,omitempty"`
}

type piLogDetails struct {
	SessionID   string `json:"sessionId,omitempty"`
	SessionName string `json:"sessionName,omitempty"`
	NativeEvent string `json:"nativeEvent,omitempty"`
}

type opencodeLogDetails struct {
	SessionID   string `json:"sessionId,omitempty"`
	NativeEvent string `json:"nativeEvent,omitempty"`
}

type commandLogDetails struct {
	Command    string `json:"command"`
	ExitCode   int    `json:"exitCode"`
	Stdout     string `json:"stdout"`
	Stderr     string `json:"stderr"`
	DurationMs int    `json:"durationMs"`
}

func cmdLogs(args []string) {
	limit := 50
	var jsonOut bool

	helpText := `Usage: agent-sessions logs [flags]

Show notification log entries from the server (for debugging).

Flags:
  --limit N      maximum entries to show (default: 50)
  --json         output raw JSON logs
  -h, --help     show help
`

	_, err := lessflags.Int("--limit", &limit).
		Bool("--json", &jsonOut).
		Help("-h,--help", helpText).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if limit < 1 {
		limit = 1
	}

	url := serverURL("/api/logs")
	resp, err := http.Get(url)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: server not reachable (port %d): %v\n", defaultPort, err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Fprintf(os.Stderr, "error: server returned status %d: %s\n", resp.StatusCode, string(respBody))
		os.Exit(1)
	}

	var entries []notifyLogEntry
	if err := json.NewDecoder(resp.Body).Decode(&entries); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to parse response: %v\n", err)
		os.Exit(1)
	}

	if jsonOut {
		out, _ := json.MarshalIndent(entries, "", "  ")
		fmt.Println(string(out))
		return
	}

	// Server returns newest first; take the last `limit` entries (oldest)
	if len(entries) > limit {
		entries = entries[len(entries)-limit:]
	}

	if len(entries) == 0 {
		fmt.Println("No log entries")
		return
	}

	for _, e := range entries {
		relTime := formatRelativeTimeISO(e.Timestamp)
		basename := filepath.Base(e.Dir)

		// Build detail line
		var details []string
		if e.Event != "" {
			details = append(details, fmt.Sprintf("event=%s", e.Event))
		}
		if e.Pi != nil {
			p := e.Pi
			if p.NativeEvent != "" {
				details = append(details, fmt.Sprintf("pi.native=%s", p.NativeEvent))
			}
			if p.SessionID != "" {
				details = append(details, fmt.Sprintf("pi.session=%s", truncateStr(p.SessionID, 12)))
			}
			if p.SessionName != "" {
				details = append(details, fmt.Sprintf("pi.name=%s", p.SessionName))
			}
		}
		if e.Opencode != nil {
			o := e.Opencode
			if o.NativeEvent != "" {
				details = append(details, fmt.Sprintf("oc.native=%s", o.NativeEvent))
			}
			if o.SessionID != "" {
				details = append(details, fmt.Sprintf("oc.session=%s", truncateStr(o.SessionID, 12)))
			}
		}

		fmt.Printf("  %s — %s\n", basename, relTime)
		fmt.Printf("    └── %s\n", e.Dir)
		if len(details) > 0 {
			for _, d := range details {
				fmt.Printf("        %s\n", d)
			}
		}

		// Show command execution result
		if c := e.Command; c != nil {
			suffix := ""
			if c.ExitCode < 0 {
				suffix = " (launch failed)"
			} else if c.ExitCode != 0 {
				suffix = fmt.Sprintf(" (exit=%d)", c.ExitCode)
			}
			fmt.Printf("        cmd=%s [%d ms]%s\n", c.Command, c.DurationMs, suffix)
			if c.Stderr != "" {
				for _, line := range strings.Split(strings.TrimRight(c.Stderr, "\n"), "\n") {
					fmt.Printf("        stderr: %s\n", line)
				}
			}
			if c.Stdout != "" {
				for _, line := range strings.Split(strings.TrimRight(c.Stdout, "\n"), "\n") {
					fmt.Printf("        stdout: %s\n", line)
				}
			}
		}
	}
}

func truncateStr(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "…"
}

// --- watch subcommand ---

func cmdWatch(args []string) {
	var dir string
	var debounceMs int = 2000

	helpText := `Usage: agent-sessions watch [flags]

Watch a directory for file changes and send notifications to the
agent sessions server when changes are detected.

This is useful for integrating with tools that don't have a built-in
extension/plugin system. Configure it to watch the session storage
directory and it will notify whenever files change.

Flags:
  --dir DIR            directory to watch (default: current working directory)
  --debounce-ms MS     minimum interval between notifications (default: 2000)
  --event EVENT        event name to send (default: session.finished)
  -h, --help           show help
`

	var event string = "session.finished"

	_, err := lessflags.String("--dir", &dir).
		String("--event", &event).
		Int("--debounce-ms", &debounceMs).
		Help("-h,--help", helpText).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if dir == "" {
		cwd, err := os.Getwd()
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: cannot get current working directory: %v\n", err)
			os.Exit(1)
		}
		dir = cwd
	}

	absDir, err := filepath.Abs(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot resolve directory %q: %v\n", dir, err)
		os.Exit(1)
	}

	if debounceMs < 100 {
		debounceMs = 100
	}

	debounce := time.Duration(debounceMs) * time.Millisecond

	fmt.Printf("Watching %s (debounce: %v)\n", absDir, debounce)
	fmt.Println("Press Ctrl+C to stop.")

	// Track file mod times
	modTimes := make(map[string]time.Time)

	// Initial scan
	updateModTimes(absDir, modTimes)

	var lastNotify time.Time
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for range ticker.C {
		oldModTimes := make(map[string]time.Time)
		for k, v := range modTimes {
			oldModTimes[k] = v
		}

		updateModTimes(absDir, modTimes)

		// Check for changes
		changed := false
		for path, newTime := range modTimes {
			oldTime, exists := oldModTimes[path]
			if !exists || newTime.After(oldTime) {
				changed = true
				break
			}
		}
		// Also check for deletions
		for path := range oldModTimes {
			if _, exists := modTimes[path]; !exists {
				changed = true
				break
			}
		}

		if changed && time.Since(lastNotify) > debounce {
			lastNotify = time.Now()
			doNotify(absDir, event)
			fmt.Printf("[%s] notification sent\n", time.Now().Format("15:04:05"))
		}
	}
}

func updateModTimes(dir string, modTimes map[string]time.Time) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		if entry.IsDir() {
			updateModTimes(path, modTimes)
		} else {
			info, err := entry.Info()
			if err == nil {
				modTimes[path] = info.ModTime()
			}
		}
	}
}

func doNotify(dir string, event string) {
	body := map[string]string{"dir": dir}
	bodyBytes, _ := json.Marshal(body)
	url := serverURL("/api/notify")
	req, _ := http.NewRequest("POST", url, bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err == nil {
		resp.Body.Close()
	}
}
