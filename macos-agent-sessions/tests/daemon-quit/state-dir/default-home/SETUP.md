# Scenario

**Feature**: default state dir under home when env unset

```go
func Setup(t *testing.T, req *Request) error {
	req.StateDirEnvValue = ""
	return nil
}
```