## Expected

- `resp.Error == ""`.
- `resp.PrettyJSON` decodes to a struct whose **source**, **dir**, **event**, and **command** sub-fields match the request `log_entry`.

## Side Effects

- No sheet UI; round-trip verified in test assert only.

## Errors

- Decode failure or field mismatch fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("test helper reported error: %s", resp.Error)
	}
	if req.LogEntry == nil {
		t.Fatal("SETUP must set log_entry")
	}
	pretty := resp.PrettyJSON
	if strings.TrimSpace(pretty) == "" {
		t.Fatal("expected non-empty pretty_json")
	}

	var decoded struct {
		Source    string              `json:"source"`
		Timestamp string              `json:"timestamp"`
		Dir       string              `json:"dir"`
		Event     string              `json:"event"`
		Command   *CommandLogDetails  `json:"command"`
	}
	if err := json.Unmarshal([]byte(pretty), &decoded); err != nil {
		t.Fatalf("pretty_json must decode: %v\n%s", err, pretty)
	}

	orig := req.LogEntry
	if decoded.Source != orig.Source {
		t.Fatalf("source: got %q want %q", decoded.Source, orig.Source)
	}
	if decoded.Dir != orig.Dir {
		t.Fatalf("dir: got %q want %q", decoded.Dir, orig.Dir)
	}
	if decoded.Event != orig.Event {
		t.Fatalf("event: got %q want %q", decoded.Event, orig.Event)
	}
	if decoded.Timestamp != orig.Timestamp {
		t.Fatalf("timestamp: got %q want %q", decoded.Timestamp, orig.Timestamp)
	}
	if orig.Command == nil {
		t.Fatal("SETUP must set command for roundtrip leaf")
	}
	if decoded.Command == nil {
		t.Fatal("decoded command must be non-nil")
	}
	if decoded.Command.Command != orig.Command.Command {
		t.Fatalf("command.command: got %q want %q", decoded.Command.Command, orig.Command.Command)
	}
	if decoded.Command.ExitCode != orig.Command.ExitCode {
		t.Fatalf("command.exitCode: got %d want %d", decoded.Command.ExitCode, orig.Command.ExitCode)
	}
	if decoded.Command.Stdout != orig.Command.Stdout {
		t.Fatalf("command.stdout: got %q want %q", decoded.Command.Stdout, orig.Command.Stdout)
	}
	if decoded.Command.Stderr != orig.Command.Stderr {
		t.Fatalf("command.stderr: got %q want %q", decoded.Command.Stderr, orig.Command.Stderr)
	}
	if decoded.Command.DurationMs != orig.Command.DurationMs {
		t.Fatalf("command.durationMs: got %d want %d", decoded.Command.DurationMs, orig.Command.DurationMs)
	}
	t.Logf("viewer/prettify-roundtrip OK: source=%q event=%q", decoded.Source, decoded.Event)
}
```