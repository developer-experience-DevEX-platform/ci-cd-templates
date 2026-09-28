# Reusable CI/CD Workflows

Reusable GitHub Actions workflows for services in this organization.

CI and CD are separate. CI, container release, and Kubernetes GitOps are
documented and released as **`v1.0.0`**. Pin that tag. The Lambda
workflows are not reviewed and are not in this version.

## Start here

1. [Getting started](docs/getting-started.md) — paste a CI caller and meet the contract
2. [Overview](docs/overview.md) — job graph, triggers, what belongs in CI
3. Your language: [Node.js](docs/ci/nodejs.md), [Python](docs/ci/python.md), [Go](docs/ci/go.md), or [Frontend](docs/ci/frontend.md)
4. [Container release](docs/cd/container-release.md) — PR build and scan; publish on push to `main`
5. [Static site release](docs/cd/static-site-release.md) — Vite build to S3 and CloudFront on `main`
6. [TechDocs publish](docs/cd/techdocs.md) — generate MkDocs in CI and store the site in S3

## CI

The [CI standard](docs/ci/README.md) is the same for every language. The
workflow runs a fixed process; the service chooses the tools.

| Runtime | Status | Docs |
| --- | --- | --- |
| Node.js | Available | [docs/ci/nodejs.md](docs/ci/nodejs.md) |
| Python | Available | [docs/ci/python.md](docs/ci/python.md) |
| Go | Available | [docs/ci/go.md](docs/ci/go.md) |
| Frontend (React + Vite) | Available | [docs/ci/frontend.md](docs/ci/frontend.md) |
| .NET | Not shipped | [docs/ci/dotnet.md](docs/ci/dotnet.md) |

Shared CI topics:

- [Integration tests](docs/ci/integration-tests.md)
- [SonarQube](docs/ci/sonarqube.md)
- [Composite actions](docs/ci/actions.md)

## CD

| Workflow | Status | Docs |
| --- | --- | --- |
| Container release | Available | [docs/cd/container-release.md](docs/cd/container-release.md) |
| Static site release | Available | [docs/cd/static-site-release.md](docs/cd/static-site-release.md) |
| Kubernetes GitOps | Available | [docs/cd/kubernetes-gitops.md](docs/cd/kubernetes-gitops.md) |
| TechDocs publish | Available | [docs/cd/techdocs.md](docs/cd/techdocs.md) |
| Node.js Lambda | Exists, not reviewed | — |

How they fit together: [docs/cd/README.md](docs/cd/README.md).

## Platform

Org secrets, Sonar permissions, ECR repository variables, and how we pin
workflow versions live in [docs/platform.md](docs/platform.md). Teams do
not need that page to adopt CI.
