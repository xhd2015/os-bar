## Expected
- `resp.MEMPercent` is a `Double` value.
- `resp.MEMPercent` is ≥ 0.0 and ≤ 100.0.

## Errors
- If `resp.MEMPercent` < 0.0, the test fails with a message indicating MEM% is below the valid minimum.
- If `resp.MEMPercent` > 100.0, the test fails with a message indicating MEM% exceeds the valid maximum.

```go
import "fmt"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}

	if resp.MEMPercent < 0.0 {
		t.Fatalf("memPercent must be >= 0.0, got %.2f", resp.MEMPercent)
	}
	if resp.MEMPercent > 100.0 {
		t.Fatalf("memPercent must be <= 100.0, got %.2f", resp.MEMPercent)
	}

	t.Logf("memPercent = %.2f (valid range [0.0, 100.0])", resp.MEMPercent)
	_ = fmt.Sprintf
}
```
