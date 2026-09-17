# Reusable CI/CD Workflows

Reusable GitHub Actions workflows for services in this organization.

CI and CD are separate. CI, container release, and Kubernetes GitOps are
documented. The Lambda workflows are not reviewed yet.

## Start here

1. [Getting started](docs/getting-started.md) — paste a CI caller and meet the contract
2. [Overview](docs/overview.md) — job graph, triggers, what belongs in CI
3. Your language: [Node.js](docs/ci/nodejs.md) or [Python](docs/ci/python.md)
4. [Container release](docs/cd/container-release.md) — PR build and scan; publish on push to `main`

## CI

The [CI standard](docs/ci/README.md) is the same for every language. The
workflow runs a fixed process; the service chooses the tools.

| Runtime | Status | Docs |
| --- | --- | --- |
| Node.js | Available | [docs/ci/nodejs.md](docs/ci/nodejs.md) |
| Python | Available | [docs/ci/python.md](docs/ci/python.md) |
| Go | Not shipped | [docs/ci/go.md](docs/ci/go.md) |
| .NET | Not shipped | [docs/ci/dotnet.md](docs/ci/dotnet.md) |

Shared CI topics:

- [Integration tests](docs/ci/integration-tests.md)
- [SonarQube](docs/ci/sonarqube.md)

## CD

| Workflow | Status | Docs |
| --- | --- | --- |
| Container release | Available | [docs/cd/container-release.md](docs/cd/container-release.md) |
| Kubernetes GitOps | Available | [docs/cd/kubernetes-gitops.md](docs/cd/kubernetes-gitops.md) |
| Node.js Lambda | Exists, not reviewed | — |

How they fit together: [docs/cd/README.md](docs/cd/README.md).

## Platform

Org secrets, Sonar permissions, ECR repository variables, and how we pin
workflow versions live in [docs/platform.md](docs/platform.md). Teams do
not need that page to adopt CI.
