# Go CI

Workflow: `.github/workflows/go-ci.yml`

Same [job graph](../overview.md) as Node.js. Go has no `package.json`
scripts, so the named commands are `Makefile` targets.

## Commands

```text
go mod download
make format-check
make lint
make test
make test-integration         only when has_integration_tests is true
```

The service must be a Go module with `go.mod` and `go.sum`. Targets must
meet this contract:

- `format-check` exits non-zero when formatting drifts.
- `lint` exits non-zero on lint violations.
- `test` runs unit tests and writes `coverage.out`.
- `test-integration` starts the suite's own dependencies and tests how
  components work together. Required only when `has_integration_tests` is
  `true`. Docker must be available; it already is on `ubuntu-latest`.

The golden path ships this Makefile, backed by gofmt, golangci-lint, and
`go test`:

```makefile
.PHONY: format-check lint test test-integration verify

format-check:
	test -z "$$(gofmt -l .)"

lint:
	golangci-lint run

test:
	go test ./... -coverprofile=coverage.out

test-integration:
	go test ./... -tags=integration -count=1

verify: format-check lint test
```

Mark integration tests with `//go:build integration` so `make test` does
not run them.

The workflow installs a pinned golangci-lint onto `PATH` before `make
lint`. Swap a tool in the service `Makefile`; the workflow does not
change. Other module managers are not supported.

SonarQube reads the module as sources, `*_test.go` as tests, and
`coverage.out`.

## Caller

```yaml
name: CI

on:
  push:
    branches-ignore:
      - main
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: true

jobs:
  ci:
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/go-ci.yml@v1.8.0
    permissions:
      contents: read
    secrets: inherit
    with:
      has_integration_tests: true
```

If `release.yml` also calls this workflow, ignore `main` on the `push`
trigger as in the snippet above. Release runs CI on merge, so a second CI
workflow on `main` is duplicate work. That `ci` job uses the same
permissions and `secrets: inherit`. Do not add `id-token: write` there;
that is only for [container release](../cd/container-release.md).

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Directory containing `go.mod`, `go.sum`, and `Makefile`. |
| `go_version` | `1.25` | |
| `has_dockerfile` | `true` | Set to `false` for Lambda. |
| `dockerfile_path` | `./Dockerfile` | Relative to the repository root. |
| `has_integration_tests` | `false` | Set to `true` for the platform job. Leave `false` to skip it or to own a separate job in the caller. |
| `integration_test_vars` | `{}` | JSON object of non-secret environment variables. |

Shared input meaning: [CI standard](README.md).

## Related

- [Integration tests](integration-tests.md)
- [SonarQube](sonarqube.md)
