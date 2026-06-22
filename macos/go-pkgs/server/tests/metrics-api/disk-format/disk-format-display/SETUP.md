# Scenario

**Feature**: FormatDiskDisplay composes percent and used/total labels for dropdown line

```
# mock tick 0 disk values
doctest -> monitor.FormatDiskDisplay(536870912000, 214748364800) -> "40% (200GB/500GB)"
```

## Steps

1. Set `req.Action = format_disk_display`.
2. Set `req.FormatDiskTotal = 536870912000`, `req.FormatDiskUsed = 214748364800`.

## Context

- Matches Swift dropdown: `Disk: 40% (200GB/500GB)` (rounded percent, used/total).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatDiskDisplay
	req.FormatDiskTotal = 536870912000
	req.FormatDiskUsed = 214748364800
	return nil
}
```