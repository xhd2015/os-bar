## Expected
- `resp.CPUPercent` is a `Double` value.
- `resp.CPUPercent` is ≥ 0.0 and ≤ 100.0.

## Errors
- If `resp.CPUPercent` < 0.0, the test fails with a message indicating CPU% is below the valid minimum.
- If `resp.CPUPercent` > 100.0, the test fails with a message indicating CPU% exceeds the valid maximum.

```go
import "fmt"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}

	if resp.CPUPercent < 0.0 {
		t.Fatalf("cpuPercent must be >= 0.0, got %.2f", resp.CPUPercent)
	}
	if resp.CPUPercent > 100.0 {
		t.Fatalf("cpuPercent must be <= 100.0, got %.2f", resp.CPUPercent)
	}

	t.Logf("cpuPercent = %.2f (valid range [0.0, 100.0])", resp.CPUPercent)
	_ = fmt.Sprintf // prevent import error if unused
}
```
