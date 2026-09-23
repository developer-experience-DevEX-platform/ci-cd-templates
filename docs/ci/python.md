# Python CI

Workflow: `.github/workflows/python-ci.yml`

Same [job graph](../overview.md) as Node.js. Python has no `package.json`
scripts, so the named commands are `Makefile` targets.

## Commands

```text
uv sync --frozen
make format-check
make lint
make test
make test-integration         only when has_integration_tests is true
```

The service must be a uv project with `pyproject.toml` and `uv.lock`.
Targets must meet this contract:

- `format-check` exits non-zero when formatting drifts.
- `lint` exits non-zero on lint violations.
- `test` runs unit tests and writes `coverage.xml`.
- `test-integration` starts the suite's own dependencies and tests how
  components work together. Required only when `has_integration_tests` is
  `true`. Docker must be available; it already is on `ubuntu-latest`.

The golden path ships this Makefile, backed by Black, Ruff, and pytest:

```makefile
.PHONY: format-check lint test test-integration verify

format-check:
	uv run black --check .

lint:
	uv run ruff check .

test:
	uv run pytest -m "not integration" --cov=src --cov-report=xml --cov-report=term-missing

test-integration:
	uv run pytest -m integration

verify: format-check lint test
```

Swap a tool in the service `Makefile`; the workflow does not change. pip,
Poetry, and pipenv are not supported.

Runtime dependencies live in `[project]` in `pyproject.toml`. Dev tools
and test libraries live in `[dependency-groups] dev`. `uv sync --frozen`
installs both. The container image uses `uv sync --frozen --no-dev`.

SonarQube reads `src` as sources, `tests` as tests, and `coverage.xml`.

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
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/python-ci.yml@v1.6.0
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
| `working_directory` | `.` | Directory containing `pyproject.toml`, `uv.lock`, and `Makefile`. |
| `python_version` | `3.13` | |
| `has_dockerfile` | `true` | Set to `false` for Lambda. |
| `dockerfile_path` | `./Dockerfile` | Relative to the repository root. |
| `has_integration_tests` | `false` | Set to `true` for the platform job. Leave `false` to skip it or to own a separate job in the caller. |
| `integration_test_vars` | `{}` | JSON object of non-secret environment variables. |

Shared input meaning: [CI standard](README.md).

## Related

- [Integration tests](integration-tests.md)
- [SonarQube](sonarqube.md)
