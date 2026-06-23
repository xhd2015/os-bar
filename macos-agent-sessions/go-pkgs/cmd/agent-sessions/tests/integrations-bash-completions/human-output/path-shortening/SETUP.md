# Scenario

**Feature**: human integrations output shortens paths via pathfmt.Short

```
# human formatter applies pathfmt.Short at print sites only
integrations handler -> human formatter -> pathfmt.Short -> stdout table

# global paths under fakeHome render as ~/...
human formatter <- pathfmt.Short (HOME=fakeHome, cwd=workDir)

# local paths under workDir render as cwd-relative .foo/...
human formatter <- pathfmt.Short (cwd=workDir)

# joined dual paths shorten each side independently
human formatter -> "~/.grok/... + .grok/..." on stdout
```

## Preconditions

- Human-readable output (`JsonOut=false`) must shorten install paths for display.
- JSON output (`--json`) is out of scope for this grouping — paths stay absolute.
- Shortening uses the same `HOME` and cwd context as the CLI exec (`fakeHome`, `workDir`).

## Steps

- Grouping node for path-display rules exercised explicitly by focused leaves below.
- Leaves set scope flags and optional seed flags; inherited `human-output` setup sets `req.Action = "integrations"`.

## Context

- `assertHumanPathShortened`, `assertNoAbsoluteTempPaths`, and `assertJoinedHumanPaths` live in the root `SETUP.md`.
- Global integration paths resolve under `resp.FakeHome`; local paths under `resp.WorkDir`.
- Human stdout must never echo absolute temp-dir prefixes from the harness.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("human-output/path-shortening: preparing path display scenario")
	return nil
}
```