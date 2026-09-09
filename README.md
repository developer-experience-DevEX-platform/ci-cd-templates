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

### Node.js integration-test secrets

Node.js services declare integration-test secrets in
`.platform/integration-tests.yaml`:

```yaml
secrets:
  - env: DB_PASSWORD
    secret: integration-db
    json_key: password
```

`env` is the environment variable exposed to the integration test, `secret` is
a single logical secret name, and `json_key` is optional. For an `orders-api`
repository, `integration-db` resolves to
`orders-api/integration/integration-db`.

Declarations are limited to 25 entries. Environment variable names must be
valid and unique. Secret names may contain letters, digits, `_`, `-`, `.`, `+`,
`=`, and `@`, but cannot contain `/`, `..`, or `:`. ARNs and paths are rejected,
so service-owned configuration cannot select an arbitrary AWS secret ARN.

When the file is absent, empty, or has no secret entries, integration tests run
without AWS authentication. Secret-backed integration tests run only for
same-repository pull requests and use the platform-provisioned OIDC role; pull
requests from forks skip the entire integration-test job.

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
