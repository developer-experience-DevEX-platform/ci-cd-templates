# Getting started

Adopt CI in one sitting. The workflow is reusable: your service keeps a thin
caller and meets a small command contract. You do not copy the job graph into
your repository.

## 1. Add a caller

Create `.github/workflows/ci.yml` in the service repo.

**Node.js**

```yaml
name: CI

on:
  push:
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: true

jobs:
  ci:
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-ci.yml@v1.6.0
    permissions:
      contents: read
    secrets: inherit
    with:
      has_integration_tests: true
```

**Python** — same file, with `python-ci.yml` instead of `nodejs-ci.yml`.

`secrets: inherit` is required so the org `SONAR_TOKEN` reaches the reusable
workflow. Set `has_integration_tests: true` when the service implements the
platform integration command. Leave it `false` to skip that job, including
when the team adds their own integration job in this caller — they own that
stage. See [integration tests](ci/integration-tests.md).

Full inputs and the command contract: [Node.js](ci/nodejs.md), [Python](ci/python.md).
When the service also has `release.yml`, ignore `main` on this caller so a
merge does not start CI and Release together. See [overview](overview.md).

## 2. Meet the contract

The workflow calls named commands. The service implements them.

| What CI runs | Node.js | Python |
| --- | --- | --- |
| Install | `npm ci` (needs `package-lock.json`) | `pip install -r requirements.txt` |
| Format | `npm run format:check` | `make format-check` |
| Lint | `npm run lint` | `make lint` |
| Unit tests + coverage | `npm test -- --coverage` → `coverage/lcov.info` | `make test` → `coverage.xml` |
| Integration tests | `npm run test:integration` | `make test-integration` |

Golden-path services already ship these scripts (Prettier, ESLint, Jest) or
Makefile targets (Black, Ruff, pytest). Change a tool in the service repo; do
not add workflow inputs for it.

## 3. Confirm it works

Push a feature branch. Format, lint, unit tests, dependency scan, and
Dockerfile lint should run. Open a pull request when those are green.

You are done when a feature-branch push is green and a pull request runs
SonarQube, then integration tests (if you enabled them).

## Next

- [How the job graph works](overview.md)
- [Hermetic integration tests](ci/integration-tests.md)
- [Reading a SonarQube failure](ci/sonarqube.md)
- [Container release](cd/container-release.md) — PR build and scan; publish only on push to `main`
