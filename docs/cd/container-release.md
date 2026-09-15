# Container release

Workflow: `.github/workflows/container-release.yml`

Builds one image, scans **that** image, then optionally publishes it to ECR
as an immutable Git SHA tag. The same `image.tar` is what Trivy, Dockle, the
SBOM, and ECR see. The workflow does not deploy.

## Job graph

```text
build-image  ->  vulnerability-scan, container-compliance  ->  sbom
publish_image true:                                         ->  publish-ecr
```

| Job | What it enforces |
| --- | --- |
| Build image | `docker build` of the service Dockerfile. Tag must be a 40-character SHA. |
| Trivy | `HIGH` and `CRITICAL` vulnerabilities fail the job. Unfixed issues are ignored. |
| Dockle | Container best-practice findings at `warn` and above fail the job. |
| SBOM | CycloneDX from the scanned image. Runs only if both scans pass. |
| Publish to ECR | OIDC into the service release role. Tag is write-once. Skipped when `publish_image` is `false`. |

## What the service must provide

A Dockerfile. The golden path ships one. Change the image contents in the
Dockerfile; do not add build-command inputs to the workflow.

`dockerfile_path` is relative to `working_directory` (the build context).
Default is `Dockerfile` in the repository root. CI's Hadolint input is
still documented as repository-root relative; if `working_directory` is not
`.`, pass matching paths in both callers.

## Callers

Two callers. Publishing is opt-in.

**Pull request — validate, do not publish.** Put this next to CI in
`.github/workflows/ci.yml`. `publish_image` defaults to `false`.

```yaml
  container-validation:
    if: github.event_name == 'pull_request'
    needs: ci
    permissions:
      contents: read
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/container-release.yml@main
```

**Push to `main` — publish.** Separate workflow, after CI:

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
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-ci.yml@main
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
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/container-release.yml@main
    with:
      publish_image: true
```

Python services use `python-ci.yml` in the `ci` job. Lambda services omit
this workflow.

`image_name` defaults to the repository name. `image_tag` defaults to
`github.sha`. Pass them only when those defaults are wrong.

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Docker build context. |
| `dockerfile_path` | `Dockerfile` | Relative to `working_directory`. |
| `image_name` | repository name | Local tag only. ECR uses `vars.ECR_REPOSITORY`. |
| `image_tag` | `github.sha` | Must be a 40-character Git SHA. `latest` is rejected. |
| `publish_image` | `false` | Set to `true` only from `main`. |

Retention of the image tarball, scan reports, and SBOM is fixed by the
platform (1 / 30 / 90 days). It is not an input.

## Publish configuration

Publishing uses GitHub Actions **repository variables**, not workflow
inputs, and GitHub OIDC — not long-lived AWS keys:

- `AWS_REGION`
- `AWS_RELEASE_ROLE_ARN`
- `ECR_REPOSITORY`

Platform provisioning (Backstage / Terraform) sets these. Teams do not
create the ECR repository or the IAM role. If they are missing, publish
fails with a clear error; PR validation (`publish_image: false`) still
runs.

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
- [Platform](../platform.md) — how those repository variables get there
- GitOps deploy after publish is a later review
