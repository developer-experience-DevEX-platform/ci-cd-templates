# Static site release

Workflow: `.github/workflows/static-site-release.yml`

Builds the Vite site, secret-scans **that** `dist/`, publishes it to the
service S3 bucket, then invalidates CloudFront. The workflow does not
run SonarQube, a CVE scan of `dist/`, or a browser test framework.
Lockfile CVEs stay in Frontend CI.

The caller skips this job until `STATIC_SITE_BUCKET` is set so the first
scaffold commit stays green. Once the variable exists, this workflow
fails if any required variable is empty. Do not skip inside the reusable
workflow.

## Job graph

```text
push to main:   build  ->  Trivy secret scan dist/  ->  s3 sync --delete  ->  CloudFront invalidate /*
```

`workflow_dispatch` does not publish. Publish is push to `main` only.

One site in v1. There is no staging bucket and no promote workflow.

## What the service must provide

`npm run build` that writes `dist/`. The golden path will ship Vite.
Change how the site is bundled in the service; do not add build-command
inputs to the workflow.

## Caller

Two files. `ci.yml` ignores `main`. `release.yml` is the only workflow
that should run on that push, and it already runs Frontend CI before
publish.

```yaml
name: Release

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  ci:
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/frontend-ci.yml@v1.12.0
    permissions:
      contents: read
    secrets: inherit

  release:
    needs: ci
    if: vars.STATIC_SITE_BUCKET != ''
    permissions:
      contents: read
      id-token: write
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/static-site-release.yml@v1.12.0

  publish-docs:
    needs: ci
    if: vars.TECHDOCS_S3_BUCKET != ''
    permissions:
      contents: read
      id-token: write
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/techdocs-publish.yml@v1.12.0
```

Pin `@v1.12.0`.

The `if` on `release` is required. A skipped reusable-workflow job never
runs the missing-variable check, so an unprovisioned repo stays green.

## Permissions

The CI job is `contents: read` and `secrets: inherit`. `id-token: write`
belongs on the jobs that talk to AWS. The `ci` job must still set
`contents: read` explicitly, or it would inherit OIDC from the workflow.

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Directory containing `package.json`. |
| `node_version` | `24` | |

## Publish configuration

Repository variables from Terraform (`static-site-release`), not workflow
inputs, and GitHub OIDC — not long-lived AWS keys:

- `AWS_REGION`
- `AWS_RELEASE_ROLE_ARN`
- `STATIC_SITE_BUCKET`
- `CLOUDFRONT_DISTRIBUTION_ID`

`TECHDOCS_S3_BUCKET` is for [TechDocs](techdocs.md), not this workflow.

The role may list the content bucket, get/put/delete objects in it, and
create an invalidation on this distribution only.

## Related

- [Frontend CI](../ci/frontend.md)
- [TechDocs publish](techdocs.md)
- [Platform](../platform.md)
