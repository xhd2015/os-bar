## Expected
- `len(resp.Integrations) == 4`.
- Each integration ID is one of: grok, opencode, pi, codex.
- Every integration has `status == "missing"`.
- Every integration has `scope == "global"`.
- Every `path` is under `resp.HomeDir` (isolation).

## Errors
- If any integration is not `missing`, the test fails with actual status.
- If `Run` returns an error, the test fails.

## Exit Code
- CLI exits 0.

```go
import (
	"path/filepath"
	"slices"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Integrations) != 4 {
		t.Fatalf("expected 4 integrations, got %d", len(resp.Integrations))
	}

	wantIDs := []string{"codex", "grok", "opencode", "pi"}
	gotIDs := make([]string, 0, 4)
	for _, item := range resp.Integrations {
		gotIDs = append(gotIDs, item.ID)
		if item.Status != "missing" {
			t.Fatalf("integration %q: expected status missing, got %q", item.ID, item.Status)
		}
		if item.Scope != "global" {
			t.Fatalf("integration %q: expected scope global, got %q", item.ID, item.Scope)
		}
		assertPathUnderHome(t, item.Path, resp.HomeDir)
	}
	slices.Sort(gotIDs)
	slices.Sort(wantIDs)
	if !slices.Equal(gotIDs, wantIDs) {
		t.Fatalf("integration IDs mismatch: got %v want %v", gotIDs, wantIDs)
	}

	t.Logf("detection/all-missing OK: home=%s", resp.HomeDir)
}
```