# Container release

Workflow: `.github/workflows/container-release.yml`

Builds one image and scans **that** image. On push to `main` it also writes
an SBOM and publishes the same tarball to ECR as an immutable Git SHA tag.
The workflow does not deploy.

The template decides when SBOM and publish run. Callers do not pass a
publish flag.

## Job graph

```text
pull_request:   build-image  ->  trivy, dockle
push to main:   build-image  ->  trivy, dockle  ->  sbom  ->  publish-ecr
```

Two Docker builds on purpose. The PR image and the `main` image are
different commits and different bytes. PR proves the Dockerfile builds and
is clean. `main` produces the SHA you tag in ECR, scans **that** tarball,
then publishes it.

| Job | PR | `main` | What it enforces |
| --- | --- | --- | --- |
| Build image | yes | yes | `docker build`. Tag must be a 40-character SHA. |
| Trivy | yes | yes | `HIGH` and `CRITICAL` fail. Unfixed issues are ignored. |
| Dockle | yes | yes | Findings at `warn` and above fail. |
| SBOM | no | yes | CycloneDX of the image you ship. |
| Publish to ECR | no | yes | OIDC into the service release role. Tag is write-once. |

## What the service must provide

A Dockerfile. The golden path ships one. Change the image contents in the
Dockerfile; do not add build-command inputs to the workflow.

`dockerfile_path` is relative to `working_directory` (the build context).
Default is `Dockerfile` in the repository root. CI's Hadolint input is
still documented as repository-root relative; if `working_directory` is not
`.`, pass matching paths in both callers.

## Callers

Two files. Keep them separate so a merge to `main` does not run this
workflow twice. `ci.yml` must ignore `main`; `release.yml` is the only
workflow that should run on that push, and it already runs CI before
publish.

**Pull request — build and scan only.** In `.github/workflows/ci.yml`:

```yaml
on:
  push:
    branches-ignore:
      - main
  pull_request:

jobs:
  container-validation:
    if: github.event_name == 'pull_request'
    needs: ci
    permissions:
      contents: read
      id-token: write
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/container-release.yml@v1.0.0
```

GitHub checks nested-job permissions at parse time, so this job still
needs `id-token: write` even though publish does not run on a PR. The
`if` keeps the job off feature-branch pushes.

**Push to `main` — build, scan, SBOM, publish.** Separate workflow:

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  ci:
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-ci.yml@v1.0.0
    permissions:
      contents: read
    secrets: inherit
    with:
      has_integration_tests: true

  release:
    needs: ci
    permissions:
      contents: read
      id-token: write
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/container-release.yml@v1.0.0
```

Python services use `python-ci.yml` in the `ci` job. Lambda services omit
this workflow.

`image_name` defaults to the repository name. `image_tag` defaults to
`github.sha`. Pass them only when those defaults are wrong.

`workflow_dispatch` on `release.yml` does not publish. Publish is push to
`main` only.

## Permissions

The CI job is the same in `ci.yml` and in `release.yml`:

```yaml
permissions:
  contents: read
secrets: inherit
```

`id-token: write` belongs on the job that publishes to ECR. `release.yml`
sets it at workflow level for that reason. The `ci` job must still set
`contents: read` explicitly, or it would inherit OIDC from the workflow.

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Docker build context. |
| `dockerfile_path` | `Dockerfile` | Relative to `working_directory`. |
| `image_name` | repository name | Local tag only. ECR uses `vars.ECR_REPOSITORY`. |
| `image_tag` | `github.sha` | Must be a 40-character Git SHA. `latest` is rejected. |

Retention of the image tarball, scan reports, and SBOM is fixed by the
platform (1 / 30 / 90 days). It is not an input.

## Publish configuration

Publishing uses GitHub Actions **repository variables**, not workflow
inputs, and GitHub OIDC — not long-lived AWS keys:

- `AWS_REGION`
- `AWS_RELEASE_ROLE_ARN`
- `ECR_REPOSITORY`

Platform provisioning (Backstage / Terraform) sets these. Teams do not
create the ECR repository or the IAM role. If they are missing, **Publish
to ECR** fails with `Missing platform configuration`. Do not skip the
`release` job when the variables are empty: a skipped job never runs that
step, so the workflow stays green. PR build and scan still run without
these variables.

The image in ECR is:

```text
<account>.dkr.ecr.<region>.amazonaws.com/<ECR_REPOSITORY>:<git-sha>
```

**Verify immutable image tag** asks ECR whether that SHA already exists. If
it does, the job fails and `docker push` never runs. A re-run after a
successful publish fails on purpose; tags are write-once. `latest` is not
used.

## Related

- [CI standard](../ci/README.md) — run CI before this workflow
- [Kubernetes GitOps](kubernetes-gitops.md) — deploys what this publishes
- [Platform](../platform.md) — how those repository variables get there
