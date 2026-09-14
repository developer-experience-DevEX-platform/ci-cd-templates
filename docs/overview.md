# Overview

CI answers: is this change safe to merge? It does not build images, publish
artifacts, or deploy.

## Job graph

Every CI workflow uses the same stages.

On **every push and every pull request**, these jobs run in parallel:

- Dockerfile lint (skipped when `has_dockerfile` is `false`, for example Lambda)
- Format and lint
- Unit tests
- Dependency scan

Dockerfile lint is not a requirement for SonarQube, so Lambda services that
skip it can still run the quality gate.

**Intended** (after SonarCloud PR analysis is available):

```text
push / pull_request:  dockerfile-lint  static-checks  unit-tests  dependency-scan
pull_request only:                 sonarqube  ->  integration-tests
```

**Today:** SonarCloud Free analyzes the default branch only, so SonarQube
runs on **push to `main`**, not on pull requests. Integration tests still run
on PRs; they treat a skipped SonarQube job as acceptable.

```text
push / pull_request:  dockerfile-lint  static-checks  unit-tests  dependency-scan
push to main:                      sonarqube
pull_request:                      integration-tests
```

Reverting SonarQube to pull requests is a one-line `if` change in the
workflows. Callers do not change.

## Triggers

The caller must use:

```yaml
on:
  push:
  pull_request:
```

| Event | What runs |
| --- | --- |
| Push to a feature branch | Parallel jobs. Confirm these before opening a PR. |
| Pull request | Parallel jobs again, then integration tests. |
| Push to `main` | Parallel jobs, then SonarQube. |

Once a pull request exists, the same commit fires both `push` and
`pull_request`, so the cheap parallel jobs run twice. That is the cost of
feature-branch CI without a PR. `concurrency` cancels a superseded run of the
same branch; it does not merge those two events into one.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: true
```

## What belongs in CI

Integration tests are **hermetic**. The suite starts its own dependencies on
the runner (Postgres, Redis, LocalStack, and so on) with Testcontainers or
Compose. CI does not inject cloud credentials.

Smoke, performance, and regression tests against a deployed environment belong
in CD, after the service is deployed.

Details: [integration tests](ci/integration-tests.md).

## Process vs tools

The reusable workflow owns the process: which stages exist, when they run, and
that they must pass. It does not take `*_command` inputs.

The service (or golden-path scaffold) owns the tools. Swap Prettier for
another formatter in `package.json`; the workflow still runs
`npm run format:check`.
