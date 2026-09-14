# Integration tests

CI integration tests are hermetic. The suite starts the service's own
dependencies on the runner. No cloud credentials, org secrets (other than
SonarQube), or OIDC are provided to this job.

The same command must work on a laptop with Docker running and in CI. The
workflow does not install or configure containers; the suite does.

## When they run

On **pull requests**, after SonarQube succeeds or is skipped, and only when
`has_integration_tests` is `true`.

They do not run on feature-branch pushes. Get format, lint, unit tests, and
the dependency scan green first, then open a PR.

## What to test

How this service's components work together: write a row and read it back,
publish to a queue and consume it. Start Postgres, Redis, LocalStack, or
whatever the service actually uses.

Do not point these tests at a deployed staging or test environment. Smoke,
performance, and regression against a live environment belong in CD.

## Do not edit the caller to add a dependency

Add a test file and a container in the suite. Jest (Node) or pytest (Python)
picks it up. `.github/workflows/ci.yml` stays as it is.

`integration_test_vars` is only for non-secret values the suite already
understands (feature flags). It is not a substitute for starting a container.

## Node.js

The golden path ships a Postgres Testcontainers sample under
`test/integration/`. Command: `npm run test:integration`.

To add S3, SQS, or other AWS APIs, add LocalStack in the suite. Copy-paste for
the scaffold lives in the generated service README. Typical packages:

```bash
npm install --save-dev @testcontainers/localstack @aws-sdk/client-s3 @aws-sdk/client-sqs
```

Point the service at the container endpoint in tests. Production leaves that
unset so the AWS SDK talks to real AWS.

| This service needs | What to do |
| --- | --- |
| Only Postgres | Keep the sample. Change tables and queries to match the schema. |
| S3 and SQS, no database | Replace the Postgres test with a LocalStack test. |
| Postgres, S3, and SQS | Keep both files. Testcontainers starts both containers. |

## Python

Use Testcontainers or Compose from `make test-integration`. Mark those tests
so `make test` (unit) does not run them. The golden-path sample will follow
the same pattern as Node.js when the Python skeleton ships.

## Docker

Required locally. GitHub-hosted `ubuntu-latest` already has it. If the suite
cannot start a container on a laptop, it will not start one in CI either.
