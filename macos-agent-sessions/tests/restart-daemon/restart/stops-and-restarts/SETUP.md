# Scenario

**Feature**: Full stop + restart cycle succeeds

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("stops-and-restarts: proceeding with full restart cycle")
	return nil
}
```