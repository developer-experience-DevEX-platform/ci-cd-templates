# TechDocs publish

Workflow: `.github/workflows/techdocs-publish.yml`

Generates the MkDocs site with the TechDocs Docker image and publishes it
to the shared platform S3 bucket. Backstage then reads that object; it
does not run MkDocs.

Call this after CI on push to `main`. It does not build a container image
and does not talk to the cluster.

## Job graph

```text
push to main:   ci  ->  publish-docs
```

| Job | What it enforces |
| --- | --- |
| Publish TechDocs | `mkdocs.yml` and `docs/index.md` exist. OIDC into the service release role. Generate then publish `default/component/<service>/`. |

## What the service must provide

`mkdocs.yml` next to `docs/index.md`. `index.md` is the homepage TechDocs
opens. Any other `.md` file under `docs/` is included automatically;
do not list filenames in `mkdocs.yml`. The golden-path Node skeleton
already ships both required files. Do not add generator-command inputs.

## Caller

In `.github/workflows/release.yml`, after CI:

```yaml
  publish-docs:
    needs: ci
    if: vars.TECHDOCS_S3_BUCKET != ''
    permissions:
      contents: read
      id-token: write
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/techdocs-publish.yml@v1.1.0
```

Skip until Terraform has written `TECHDOCS_S3_BUCKET` so the first
scaffold commit stays green. Once the job runs, missing variables fail
the workflow. Do not skip inside the reusable workflow.

`service_name` defaults to the repository name, which must match
`metadata.name` in `catalog-info.yaml`.

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Directory with `mkdocs.yml` and `docs/`. |
| `service_name` | repository name | Catalog entity name. Lowercase kebab-case. |

## Publish configuration

Publishing uses GitHub Actions **repository variables**, not workflow
inputs, and GitHub OIDC — not long-lived AWS keys:

- `AWS_REGION`
- `AWS_RELEASE_ROLE_ARN` (same role as container release)
- `TECHDOCS_S3_BUCKET`

Platform provisioning sets these. The role may write only:

```text
s3://<TECHDOCS_S3_BUCKET>/default/component/<service_name>/
```

MkDocs runs in Docker on the GitHub-hosted runner. Python is not
installed on the Backstage host.

## Related

- [CI standard](../ci/README.md) — run CI before this workflow
- [Container release](container-release.md) — same OIDC role, different artifact
- [Platform](../platform.md) — how those repository variables get there
