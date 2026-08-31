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

## CD workflows

CD workflows will be added later. They will handle capabilities such as:

- Docker image builds
- Container vulnerability scanning
- Azure OIDC authentication
- Pushing images to Azure Container Registry
- Deployment
