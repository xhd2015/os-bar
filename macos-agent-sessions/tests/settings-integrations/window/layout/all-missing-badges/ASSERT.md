## Expected
- For each integration status identifier (`integration-*-status`): `Title == "Missing"`.
- For each install identifier (`integration-*-install`): node exists with `Role == "AXButton"`.
- `resp.WindowOpen == true`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Layout == nil {
		t.Fatal("expected non-nil layout")
	}

	statusIDs := []string{
		"integration-grok-status",
		"integration-opencode-status",
		"integration-pi-status",
		"integration-codex-status",
	}
	for _, statusID := range statusIDs {
		node := findByIdentifier(resp.Layout, statusID)
		if node == nil {
			t.Fatalf("layout missing status node %q", statusID)
		}
		if node.Title != "Missing" {
			t.Fatalf("%s: expected title Missing, got %q", statusID, node.Title)
		}
	}

	installIDs := []string{
		"integration-grok-install",
		"integration-opencode-install",
		"integration-pi-install",
		"integration-codex-install",
	}
	for _, installID := range installIDs {
		node := findByIdentifier(resp.Layout, installID)
		if node == nil {
			t.Fatalf("layout missing install button %q", installID)
		}
		if node.Role != "AXButton" {
			t.Fatalf("%s: expected role AXButton, got %q", installID, node.Role)
		}
	}

	t.Logf("window/layout/all-missing-badges OK")
}
```