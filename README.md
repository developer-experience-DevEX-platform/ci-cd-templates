# Reusable CI/CD Workflows

This repository contains reusable GitHub Actions workflows for services created through the DevEx platform's golden paths.

CI and CD are intentionally separated so that service validation remains independent from build, publishing, and deployment concerns.

## Supported runtimes

- Node.js
- Python
- Go
- .NET

## CI standard

Every CI workflow will eventually include:

- Formatting
- Linting
- Unit tests
- Dependency scanning
- Integration tests

Jobs run in two phases. Static checks (formatting and linting), Dockerfile
lint, unit tests and dependency scanning run in parallel on every push and pull
request. On pull requests only, SAST runs after those pass, and integration
tests run after SAST passes.

```text
push / pull_request:  dockerfile-lint  static-checks  unit-tests  dependency-scan
pull_request only:                 sast  ->  integration-tests
```

CI integration tests are hermetic. The suite starts the service's own
dependencies on the runner (Postgres, Redis, LocalStack, and so on) with
Testcontainers or Docker Compose. No cloud credentials or secrets are
provided. Tests against a deployed staging or test environment — smoke,
performance, regression — belong to CD after the service is deployed.

## Node.js CI

`nodejs-ci.yml` runs a fixed set of npm commands. The service decides which
tools implement them.

```text
npm ci
npm run format:check
npm run lint
npm test -- --coverage
npm run test:integration      only when has_integration_tests is true
```

The service must be an npm project with a `package-lock.json`, and its
`package.json` scripts must meet this contract:

- `format:check` exits non-zero when formatting drifts.
- `lint` exits non-zero on lint violations.
- `test` runs the unit tests and, when passed `--coverage`, writes
  `coverage/lcov.info`. The coverage report feeds the code-quality gate.
- `test:integration` starts the suite's own dependencies and tests how the
  service's components work together (write to a database, publish to a
  queue). Only required when `has_integration_tests` is `true`. Docker must
  be available; it already is on `ubuntu-latest`.

Services created from the golden path ship with these scripts backed by
Prettier, ESLint and Jest, which are the tools the platform supports. A team
may swap a tool by changing the script in its own `package.json`; the workflow
does not change. Other package managers are not supported by this workflow.

The golden path ships a Postgres Testcontainers sample so
`npm run test:integration` is the same command on a laptop with Docker
running and in CI. The workflow does not install or configure containers;
the suite does.

To add S3, SQS, or other AWS APIs, the service adds
`@testcontainers/localstack` and a test file under `test/integration/`. Jest
picks it up automatically. The caller workflow does not change. The generated
service README has the copy-paste steps.

### Service wiring

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read
  security-events: write
  actions: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ci:
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-ci.yml@main
    permissions:
      contents: read
      security-events: write
      actions: read
    with:
      has_integration_tests: true
```

The trigger shape matters. A pull request branch receives both `push` and
`pull_request` events for every commit, so triggering on both runs the
parallel jobs twice on the same commit. Triggering on `pull_request` plus
`push` to `main` runs each commit once: feature branches are validated through
their pull request, and `main` is validated after merge. To get CI on a branch
before it is ready for review, open a draft pull request.

`concurrency` cancels the previous run of the same branch when a new commit is
pushed, so a fix pushed while SAST is still running does not pay for the
superseded run.

### Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Directory containing `package.json`. |
| `node_version` | `24` | |
| `has_dockerfile` | `true` | Set to `false` for Lambda services. |
| `dockerfile_path` | `./Dockerfile` | Relative to the repository root. |
| `has_integration_tests` | `false` | Set to `true` once the service has a `test:integration` script. |
| `integration_test_vars` | `{}` | JSON object of non-secret environment variables, for example feature flags. |

### Repository configuration

The caller must grant `security-events: write` and `actions: read` for SAST.
These are repository permissions, so they cannot be granted by the reusable
workflow itself. CI does not assume an AWS role and does not read secrets.

## Python CI

`python-ci.yml` has the same job graph and the same shape of contract as the
Node.js workflow. Python has no `package.json` scripts, so the indirection
between "what the workflow runs" and "which tool runs" is a `Makefile`.

```text
pip install -r requirements.txt
make format-check
make lint
make test
make test-integration         only when has_integration_tests is true
```

The service must be a pip project with a `requirements.txt`, and its
`Makefile` targets must meet this contract:

- `format-check` exits non-zero when formatting drifts.
- `lint` exits non-zero on lint violations.
- `test` runs the unit tests and writes `coverage.xml`. The coverage report
  feeds the code-quality gate.
- `test-integration` starts the suite's own dependencies and tests how the
  service's components work together. Only required when
  `has_integration_tests` is `true`. Docker must be available; it already is
  on `ubuntu-latest`.

Services created from the golden path ship with this `Makefile`, backed by
Black, Ruff and pytest, which are the tools the platform supports:

```makefile
.PHONY: format-check lint test test-integration

format-check:
	black --check .

lint:
	ruff check .

test:
	pytest -m "not integration" --cov=. --cov-report=xml --cov-report=term-missing

test-integration:
	pytest -m integration
```

A team may swap a tool by changing the target in its own `Makefile`; the
workflow does not change. Other package managers are not supported by this
workflow.

The caller workflow is the same as the Node.js one, with
`python-ci.yml` in place of `nodejs-ci.yml`. Inputs are the same, with
`python_version` (default `3.13`) in place of `node_version`. The golden path
will ship a Testcontainers sample so `make test-integration` is the same
command locally and in CI.

## Node.js Lambda contract

Three workflows split the path from commit to running function. Each one owns a
single concern and hands the next a value it cannot derive itself.

```text
nodejs-lambda-package.yml       builds and checksums a reproducible ZIP
        |  checksum_base64
nodejs-lambda-release.yml       publishes that ZIP to a write-once S3 key
        |  artifact_checksum_base64
nodejs-lambda-staging-deploy.yml  deploys that key and publishes a version
```

### Packaging

`nodejs-lambda-package.yml` packages an already validated Node.js Lambda as a
GitHub Actions artifact named `lambda-package-<git-sha>`. The build must produce
`dist/handler.js` exporting `handler`, so the Lambda handler setting is
`dist/handler.handler`.

The ZIP root contains only `dist/`, production `node_modules/`, and
`package.json`. It is built reproducibly: entry order is sorted, timestamps are
pinned to the ZIP epoch, and Unix extra fields are dropped, so rebuilding a
commit yields a byte-identical archive. The workflow performs no AWS
authentication, upload, or deployment.

`working_directory` is the only input. The Node.js version is fixed by the
platform because Terraform owns the function's runtime, and the install and
build commands are fixed because the rest of the workflow (`npm ci` caching,
`npm prune --omit=dev`) is npm-specific anyway.

### Release

`nodejs-lambda-release.yml` runs packaging, verifies the downloaded artifact
against its checksum, and uploads `function.zip` to
`<service>/<40-character-git-sha>/function.zip`.

AWS region, publishing role, and artifact bucket come from Terraform-managed
repository variables. The upload uses GitHub OIDC and is write-once: S3 enforces
both `If-None-Match: *` and the expected SHA-256, so an existing key with
different content is rejected server side. Re-running a release that already
published identical bytes succeeds, so a partially failed run is always safe to
retry.

Releases run only for a push to `main`. A wrong trigger fails the run rather
than skipping it. To validate packaging on pull requests, call
`nodejs-lambda-package.yml` directly from the service's CI workflow.

### Staging deployment

`nodejs-lambda-staging-deploy.yml` takes one input, the base64 SHA-256 checksum
emitted by the release workflow. It derives the S3 key from the same commit and
repository, assumes the platform-managed staging role through GitHub OIDC,
updates `$LATEST` from that exact object, verifies Lambda's reported
`CodeSha256` against the released checksum, and publishes a version guarded by
both `CodeSha256` and `RevisionId`.

It does not rebuild the ZIP, change function configuration, or deploy
production.

### Service wiring

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: read
  actions: read
  id-token: write

jobs:
  release:
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-lambda-release.yml@main
    permissions:
      contents: read
      actions: read
      id-token: write

  deploy-staging:
    needs: release
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-lambda-staging-deploy.yml@main
    with:
      artifact_checksum_base64: ${{ needs.release.outputs.artifact_checksum_base64 }}
    permissions:
      contents: read
      id-token: write
```

## CD workflows

CD workflows will be added later. They will handle capabilities such as:

- Docker image builds
- Container vulnerability scanning
- Azure OIDC authentication
- Pushing images to Azure Container Registry
- Deployment
