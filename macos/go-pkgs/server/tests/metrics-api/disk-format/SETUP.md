# Scenario

**Feature**: disk byte values formatted as dual 1024-based and decimal labels

```
# 1024-based labels
doctest -> monitor.FormatDiskBytesBinaryUsed(bytes) -> "200.00GB"
doctest -> monitor.FormatDiskBytesBinaryTotal(bytes) -> "500GB"

# decimal labels (macOS Settings style)
doctest -> monitor.FormatDiskBytesDecimal(bytes) -> "536.87GB" | "214.75GB" | "0B"

# composed dropdown line
doctest -> monitor.FormatDiskDisplay(total, used) -> "40% (200.00GB/500GB, 214.75GB/536.87GB on MacOS Settings)"
```

## Preconditions

- `monitor.FormatDiskBytesBinaryUsed`, `FormatDiskBytesBinaryTotal`, `FormatDiskBytesDecimal`, and `FormatDiskDisplay` exist in `go-pkgs/monitor`.
- Binary used: two fractional digits; binary total: integer GB; decimal: two fractional digits.
- Percent rounded: `(used*100 + total/2) / total`; zero total → `"0% (0B/0B)"`.

## Steps

1. Format leaves set `req.Action` to a disk format action.
2. Input values set via `FormatBytesInput` or `FormatDiskTotal`/`FormatDiskUsed`.
3. `Run` stores formatted string in `resp.FormatResult` (no daemon subprocess).

## Context

- Mirrors Swift dropdown: `Disk: 99% (454.35GB/460GB, 488.06GB/494.38GB on MacOS Settings)`.

```go
func Setup(t *testing.T, req *Request) error {
	req.MockMetrics = false
	return nil
}
```