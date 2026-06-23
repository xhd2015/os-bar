## Expected

- `resp.Error == ""`.
- `resp.PrettyJSON` is non-empty.
- Pretty JSON contains `"source"` and `"dir"` keys with original values.
- Output is **pretty-printed**: contains newlines and indentation (leading spaces on inner lines).

## Side Effects

- No sheet UI; only `LogsEntryJSON.prettify` string output.

## Errors

- Missing keys, single-line JSON, or invalid JSON fails the test.

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
	pretty := resp.PrettyJSON
	if strings.TrimSpace(pretty) == "" {
		t.Fatal("expected non-empty pretty_json")
	}
	if !strings.Contains(pretty, "\n") {
		t.Fatalf("pretty_json must contain newlines (pretty-printed); got %q", pretty)
	}
	if !strings.Contains(pretty, "  ") {
		t.Fatalf("pretty_json must be indented; got %q", pretty)
	}
	for _, substr := range []string{`"source"`, `"pi"`, `"dir"`, `"/Users/me/proj/my-app"`} {
		if !strings.Contains(pretty, substr) {
			t.Fatalf("pretty_json %q must contain %q", pretty, substr)
		}
	}
	var obj map[string]interface{}
	if err := json.Unmarshal([]byte(pretty), &obj); err != nil {
		t.Fatalf("pretty_json must be valid JSON: %v\n%s", err, pretty)
	}
	t.Logf("viewer/prettify-entry-json OK: pretty_json length=%d", len(pretty))
}
```