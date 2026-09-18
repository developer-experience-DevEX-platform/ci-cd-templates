# Overview

CI answers: is this change safe to merge? It does not publish artifacts or
deploy. Pull-request callers may run [container release](cd/container-release.md)
to build and scan the image. Publish happens only on push to `main`.

## Job graph

Every CI workflow uses the same stages.

On **every push and every pull request**, these jobs run in parallel:

- Dockerfile lint (skipped when `has_dockerfile` is `false`, for example Lambda)
- Format and lint
- Unit tests
- Dependency scan

Dockerfile lint is not a requirement for SonarQube, so Lambda services that
skip it can still run the quality gate.

```text
push / pull_request:  dockerfile-lint  static-checks  unit-tests  dependency-scan
pull_request only:                 sonarqube  ->  integration-tests
```

## Triggers

The caller must use:

```yaml
on:
  push:
    branches-ignore:
      - main
  pull_request:
```

| Event | What runs |
| --- | --- |
| Push to a feature branch | Parallel jobs. Confirm these before opening a PR. |
| Pull request | Parallel jobs again, then SonarQube, then integration tests. |
| Push to `main` | `release.yml` only: CI (parallel jobs), then publish, then GitOps. Missing AWS vars fail publish; do not skip that job. |

`ci.yml` ignores `main` so a merge does not start CI and Release at the same
time. Release already calls the CI workflow before it publishes.

Once a pull request exists, the same commit fires both `push` and
`pull_request`, so the cheap parallel jobs run twice. That is the cost of
feature-branch CI without a PR. Put `github.event_name` in the concurrency
group so those two events do not cancel each other. A newer commit still
cancels an in-progress run of the **same** event on that branch.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: true
```

## What belongs in CI

The platform integration-test job is **hermetic**. The suite starts its own
dependencies on the runner (Postgres, Redis, LocalStack, and so on) with
Testcontainers or Compose. That job does not inject cloud credentials.

A team can leave `has_integration_tests: false` and add their own
integration job in the caller. They own that stage: secrets, runners, and
reliability. The reusable workflow does not grow inputs to support it.

Smoke, performance, and regression tests against a deployed environment belong
in CD, after the service is deployed.

Details: [integration tests](ci/integration-tests.md).

## Process vs tools

The reusable workflow owns the process: which stages exist, when they run, and
that they must pass. It does not take `*_command` inputs.

The service (or golden-path scaffold) owns the tools. Swap Prettier for
another formatter in `package.json`; the workflow still runs
`npm run format:check`.
