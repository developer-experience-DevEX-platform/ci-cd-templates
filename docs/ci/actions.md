# Composite actions

Reusable workflows call these from the same repository with a relative
path. Callers still pin one workflow tag; they do not pin the action.

| Action | What it does | Used by |
| --- | --- | --- |
| `setup-npm` | Checkout, Node.js, `npm ci` | Node.js CI, Frontend CI, static site release, Lambda package |
| `setup-uv` | Checkout, uv, `uv sync --frozen` | Python CI |
| `setup-go` | Checkout, Go, `go mod download` | Go CI |
| `trivy-fs` | Checkout, Trivy filesystem `CRITICAL,HIGH` | All four language CI workflows |
| `hadolint` | Checkout, Hadolint | Node.js, Python, and Go CI |
| `sonar-provision` | Find or create the SonarCloud project | All four language CI workflows |

Format, test, build, golangci-lint, Sonar scan args, and the `dist/`
secret scan stay in the job. Container image scans stay in container
release.

## Dependabot

A `github-actions` update watches each action directory so pinned SHAs
move with the workflows.
