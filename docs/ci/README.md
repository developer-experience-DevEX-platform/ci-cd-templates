# CI standard

Every language CI workflow implements the same process. Language pages only
document commands, coverage files, and inputs that differ.

## Stages

| Job | When | What it enforces |
| --- | --- | --- |
| Dockerfile lint | Every push and PR, if `has_dockerfile` | Hadolint on the Dockerfile |
| Format & lint | Every push and PR | Formatting drift and lint violations |
| Unit tests | Every push and PR | Tests pass and a coverage file is produced |
| Dependency scan | Every push and PR | Trivy filesystem scan; `CRITICAL` and `HIGH` fail the job |
| SonarQube | Pull requests, after the jobs above | Coverage uploaded; organization quality gate |
| Integration tests | Pull requests, if enabled | Hermetic suite after SonarQube succeeds |

Lint still runs if format fails, so both can be fixed in one push.

Timeouts are set on every job. Do not remove them in a fork of the caller;
the reusable workflow already owns them.

## Shared inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Directory that contains the language manifest (`package.json` or `requirements.txt`). |
| `has_dockerfile` | `true` | Set to `false` for Lambda services. |
| `dockerfile_path` | `./Dockerfile` | Path relative to the **repository root**, not `working_directory`. |
| `has_integration_tests` | `false` | Set to `true` to run the platform hermetic job. Leave `false` to skip it, including when the team owns a separate job in the caller. |
| `integration_test_vars` | `{}` | JSON object of non-secret environment variables (feature flags, and similar). |

Runtime version (`node_version`, `python_version`, …) is language-specific.

## Secrets

Callers pass `secrets: inherit`. The reusable workflow requires `SONAR_TOKEN`
from the GitHub organization. Teams do not create a per-repo token.

The CI job is `permissions: contents: read` in every caller, including the
`ci` job inside `release.yml`. OIDC (`id-token: write`) is only for
container publish, not for CI.

[SonarQube for teams](sonarqube.md) · [Platform setup](../platform.md)

## Customize in the service, not the caller

Supported changes in the service repo:

- Which formatter, linter, or test runner implements the named commands
- What the platform integration suite starts (Postgres, LocalStack, …)
- Layout under `src` / tests, as long as coverage still lands where Sonar
  expects
- Extra jobs in the **caller** (a team-owned integration stage, with
  `has_integration_tests: false`). The team owns the cost of that job.

Not supported:

- Extra workflow inputs that run arbitrary shell
- A different package manager than the one the workflow installs with
- Cloud credentials **inside** the reusable workflow

## Language pages

- [Node.js](nodejs.md)
- [Python](python.md)
- [Go](go.md) (not shipped)
- [.NET](dotnet.md) (not shipped)
