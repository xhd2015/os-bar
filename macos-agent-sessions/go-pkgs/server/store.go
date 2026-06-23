package server

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const (
	maxSessionEvents = 20
	maxNotifyLogs    = 200
	pruneInterval    = 7 * 24 * time.Hour
)

// SessionEvent is a session notification event stored on disk.
type SessionEvent struct {
	ID        string `json:"id"`
	Dir       string `json:"dir"`
	Timestamp string `json:"timestamp"`
	Consumed  bool   `json:"consumed"`
}

// NotifyLogEntry is a notify log record stored on disk.
type NotifyLogEntry struct {
	Source    string              `json:"source"`
	Timestamp string              `json:"timestamp"`
	Dir       string              `json:"dir"`
	Event     string              `json:"event,omitempty"`
	Pi        *PiLogDetails       `json:"pi,omitempty"`
	Opencode  *OpencodeLogDetails `json:"opencode,omitempty"`
	Command   *CommandLogDetails  `json:"command,omitempty"`
}

// PiLogDetails captures pi-specific notify payload fields.
type PiLogDetails struct {
	SessionID   string `json:"sessionId,omitempty"`
	SessionName string `json:"sessionName,omitempty"`
	NativeEvent string `json:"nativeEvent,omitempty"`
}

// OpencodeLogDetails captures opencode-specific notify payload fields.
type OpencodeLogDetails struct {
	SessionID   string `json:"sessionId,omitempty"`
	NativeEvent string `json:"nativeEvent,omitempty"`
}

// CommandLogDetails captures command execution details in notify logs.
type CommandLogDetails struct {
	Command    string `json:"command"`
	ExitCode   int    `json:"exitCode"`
	Stdout     string `json:"stdout"`
	Stderr     string `json:"stderr"`
	DurationMs int    `json:"durationMs"`
}

type store struct {
	stateDir string
	mu       sync.Mutex
	events   []SessionEvent
	logs     []NotifyLogEntry
}

func newStore(stateDir string) (*store, error) {
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return nil, err
	}
	s := &store{stateDir: stateDir}
	if err := s.loadEvents(); err != nil {
		return nil, err
	}
	if err := s.loadLogs(); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *store) eventsPath() string {
	return filepath.Join(s.stateDir, "events.json")
}

func (s *store) logsPath() string {
	return filepath.Join(s.stateDir, "notify-logs.jsonl")
}

func (s *store) legacyLogsPath() string {
	return filepath.Join(s.stateDir, "notify-logs.json")
}

func (s *store) loadEvents() error {
	data, err := os.ReadFile(s.eventsPath())
	if err != nil {
		if os.IsNotExist(err) {
			s.events = nil
			return nil
		}
		return err
	}
	var loaded []SessionEvent
	if len(data) > 0 {
		if err := json.Unmarshal(data, &loaded); err != nil {
			s.events = nil
			return nil
		}
	}
	s.events = pruneAndSortEvents(loaded)
	return s.saveEventsLocked()
}

func (s *store) loadLogs() error {
	if _, err := os.Stat(s.logsPath()); err == nil {
		return s.loadJSONL(s.logsPath())
	} else if !os.IsNotExist(err) {
		return err
	}

	legacyPath := s.legacyLogsPath()
	data, err := os.ReadFile(legacyPath)
	if err != nil {
		if os.IsNotExist(err) {
			s.logs = nil
			return nil
		}
		return err
	}
	if len(data) == 0 {
		s.logs = nil
		return os.Remove(legacyPath)
	}
	var loaded []NotifyLogEntry
	if err := json.Unmarshal(data, &loaded); err != nil {
		s.logs = nil
		return nil
	}
	s.logs = loaded
	if len(s.logs) > maxNotifyLogs {
		s.logs = s.logs[len(s.logs)-maxNotifyLogs:]
	}
	if err := s.saveLogsLocked(); err != nil {
		return err
	}
	return os.Remove(legacyPath)
}

func (s *store) loadJSONL(path string) error {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			s.logs = nil
			return nil
		}
		return err
	}
	defer f.Close()

	var loaded []NotifyLogEntry
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var entry NotifyLogEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}
		loaded = append(loaded, entry)
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	s.logs = loaded
	if len(s.logs) > maxNotifyLogs {
		s.logs = s.logs[len(s.logs)-maxNotifyLogs:]
		return s.saveLogsLocked()
	}
	return nil
}

func (s *store) saveEventsLocked() error {
	data, err := json.Marshal(s.events)
	if err != nil {
		return err
	}
	return os.WriteFile(s.eventsPath(), data, 0644)
}

func (s *store) saveLogsLocked() error {
	var buf bytes.Buffer
	for _, entry := range s.logs {
		line, err := json.Marshal(entry)
		if err != nil {
			return err
		}
		buf.Write(line)
		buf.WriteByte('\n')
	}
	return os.WriteFile(s.logsPath(), buf.Bytes(), 0644)
}

func (s *store) listEvents() []SessionEvent {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]SessionEvent, len(s.events))
	copy(out, s.events)
	return out
}

func (s *store) eventCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.events)
}

func (s *store) nextTimestamp() time.Time {
	now := time.Now()
	var maxTime time.Time
	for _, ev := range s.events {
		if t := parseEventTime(ev.Timestamp); t.After(maxTime) {
			maxTime = t
		}
	}
	if !now.After(maxTime) {
		now = maxTime.Add(time.Millisecond)
	}
	return now
}

func (s *store) addEvent(dir string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := formatTimestamp(s.nextTimestamp())
	for i, ev := range s.events {
		if ev.Dir == dir {
			s.events[i].Timestamp = now
			s.events[i].Consumed = false
			sortAndCapEvents(&s.events)
			_ = s.saveEventsLocked()
			return
		}
	}
	s.events = append(s.events, SessionEvent{
		ID:        newUUID(),
		Dir:       dir,
		Timestamp: now,
		Consumed:  false,
	})
	sortAndCapEvents(&s.events)
	_ = s.saveEventsLocked()
}

func (s *store) markConsumed(dir string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, ev := range s.events {
		if ev.Dir == dir {
			s.events[i].Consumed = true
			_ = s.saveEventsLocked()
			return
		}
	}
}

func (s *store) removeEvents(dir string) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	before := len(s.events)
	s.events = removeEventsByDir(s.events, dir)
	removed := before - len(s.events)
	if removed > 0 {
		_ = s.saveEventsLocked()
	}
	return removed
}

func (s *store) appendLog(entry NotifyLogEntry) {
	s.mu.Lock()
	defer s.mu.Unlock()

	line, err := json.Marshal(entry)
	if err != nil {
		return
	}
	f, err := os.OpenFile(s.logsPath(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	_, _ = f.Write(line)
	_, _ = f.Write([]byte("\n"))
	_ = f.Close()

	s.logs = append(s.logs, entry)
	if len(s.logs) > maxNotifyLogs {
		s.logs = s.logs[len(s.logs)-maxNotifyLogs:]
		_ = s.saveLogsLocked()
	}
}

func (s *store) listLogs() []NotifyLogEntry {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]NotifyLogEntry, len(s.logs))
	copy(out, s.logs)
	return out
}

func sortAndCapEvents(events *[]SessionEvent) {
	sortEventsNewestFirst(events)
	if len(*events) > maxSessionEvents {
		*events = (*events)[:maxSessionEvents]
	}
}

func sortEventsNewestFirst(events *[]SessionEvent) {
	evs := *events
	for i := 0; i < len(evs); i++ {
		for j := i + 1; j < len(evs); j++ {
			if parseEventTime(evs[j].Timestamp).After(parseEventTime(evs[i].Timestamp)) {
				evs[i], evs[j] = evs[j], evs[i]
			}
		}
	}
	*events = evs
}

func pruneAndSortEvents(loaded []SessionEvent) []SessionEvent {
	cutoff := time.Now().Add(-pruneInterval)
	pruned := make([]SessionEvent, 0, len(loaded))
	for _, ev := range loaded {
		if parseEventTime(ev.Timestamp).After(cutoff) {
			pruned = append(pruned, ev)
		}
	}
	sortAndCapEvents(&pruned)
	return pruned
}

func removeEventsByDir(events []SessionEvent, dir string) []SessionEvent {
	out := events[:0]
	for _, ev := range events {
		if ev.Dir != dir {
			out = append(out, ev)
		}
	}
	return out
}

func parseEventTime(ts string) time.Time {
	for _, layout := range []string{time.RFC3339Nano, time.RFC3339, "2006-01-02T15:04:05.000Z", "2006-01-02T15:04:05Z"} {
		if t, err := time.Parse(layout, ts); err == nil {
			return t
		}
	}
	return time.Time{}
}

func formatTimestamp(t time.Time) string {
	return t.UTC().Format("2006-01-02T15:04:05.000Z")
}

func newUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

// ResolveStateDir resolves the daemon state directory from flag or environment.
func ResolveStateDir(flagValue string) (string, error) {
	if flagValue != "" {
		return flagValue, nil
	}
	if env := os.Getenv("AGENT_SESSIONS_STATE_DIR"); env != "" {
		return env, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".os-bar", "agent-sessions"), nil
}