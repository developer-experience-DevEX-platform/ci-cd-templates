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
a relative name within the service's Secrets Manager namespace, and `json_key`
is optional. For an `orders-api` repository, `integration-db` resolves to
`orders-api/integration-db`.

Declarations are limited to 25 entries. Environment variable names must be
valid and unique. Secret names cannot be ARNs, absolute paths, or contain `..`
or `:`. Arbitrary AWS secret ARNs are not accepted from service-owned config.

When the file is absent, empty, or has no secret entries, integration tests run
without AWS authentication. Secret-backed integration tests run only for
same-repository pull requests and use the platform-provisioned OIDC role; pull
requests from forks skip the entire integration-test job.

## CD workflows

CD workflows will be added later. They will handle capabilities such as:

- Docker image builds
- Container vulnerability scanning
- Azure OIDC authentication
- Pushing images to Azure Container Registry
- Deployment
