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

## Node.js Lambda package contract

`nodejs-lambda-package.yml` packages an already validated Node.js Lambda as an
immutable GitHub Actions artifact named `lambda-package-<git-sha>`. The build
must produce `dist/handler.js` exporting `handler`; the future AWS Lambda
handler setting is therefore `dist/handler.handler`.

The ZIP root contains only `dist/`, production `node_modules/`, and
`package.json`. The workflow uploads `function.zip` with
`function.zip.sha256`, and also exposes the SHA-256 digest as its `checksum`
output. It performs no AWS authentication, upload, or deployment.

Lambda releases keep packaging, immutable publication, and deployment separate:

```text
nodejs-lambda-package.yml
    -> creates and checksums the immutable ZIP
nodejs-lambda-release.yml
    -> verifies and conditionally publishes that ZIP to the service's S3 prefix
future lambda-cd.yml
    -> deploys that exact S3 artifact
```

The release workflow accepts only packaging inputs. AWS region, publishing
role, and shared artifact bucket come from Terraform-managed repository
variables. Publishing runs only for a push to `main`, uses GitHub OIDC, and
refuses to overwrite an existing SHA-addressed object.

## CD workflows

CD workflows will be added later. They will handle capabilities such as:

- Docker image builds
- Container vulnerability scanning
- Azure OIDC authentication
- Pushing images to Azure Container Registry
- Deployment
