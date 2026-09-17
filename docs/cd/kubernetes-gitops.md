# Kubernetes GitOps

Two workflows:

- `kubernetes-gitops-cd.yml` — staging, automatic after a container release
- `kubernetes-gitops-production-promotion.yml` — production, manual

Neither talks to the cluster. They write the released Git SHA into
`platform-gitops`, and Argo CD syncs from there.

```text
push to main:   container-release  ->  gitops staging
manual:         gitops production  (only a SHA staging is already running)
```

## What they change

| Environment | File | Change |
| --- | --- | --- |
| Staging | `environments/staging/<service>/values.yaml` | `.image.tag` = released SHA |
| Production | `environments/production/<service>/values.yaml` | `.image.tag` = promoted SHA |
| Production | `environments/production/<service>/promotion.yaml` | Created on the first promotion |

Backstage creates those values files when the service is scaffolded. The
workflow fails if a values file is missing rather than inventing one.

`promotion.yaml` is what the production ApplicationSet looks for, so a
service is not deployed to production until someone promotes it once.

## Callers

Both live in the service repo and are thin. `secrets: inherit` passes the
org `PLATFORM_GITOPS_TOKEN`. Service name defaults to the repository name,
and the GitOps repository and branch are platform defaults.

**Staging** — add to `.github/workflows/release.yml`, after the release job:

```yaml
  deploy-staging:
    name: Deploy to staging
    needs: release
    permissions:
      contents: read
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/kubernetes-gitops-cd.yml@main
    secrets: inherit
```

`release.yml` triggers on push to `main` only. Do not add
`workflow_dispatch`: a dispatch run does not publish to ECR, so staging
would point at an image that was never pushed.

**Production** — `.github/workflows/promote-production.yml`:

```yaml
name: Promote Production

on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: Immutable Git SHA already validated in staging.
        required: true
        type: string

permissions:
  contents: read

jobs:
  promote-production:
    permissions:
      contents: read
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/kubernetes-gitops-production-promotion.yml@main
    secrets: inherit
    with:
      image_tag: ${{ inputs.image_tag }}
```

## Deploying to production

Run **Promote Production** and paste the SHA staging is running. The job
uses the GitHub `production` environment, so any reviewers you configure
there approve it.

Promotion is rejected when staging does not currently reference that SHA.
Production runs the same image bytes staging tested; nothing is rebuilt and
`latest` is never used.

## When staging is skipped

If a newer commit reached `main` while this run was in flight, staging is
skipped and the job still **succeeds**. Writing the older SHA would roll
staging back. The log names the SHA that superseded this one.

Worked example. Dev A adds a login button and merges. Dev B adds a logout
button and merges just after, so `main` now has both. Each merge builds its
own image: A's has login, B's has login and logout.

| Which run pushes first | Result |
| --- | --- |
| A, then B | A writes A, B writes B. Staging runs B. |
| B, then A | B writes B. A sees it is no longer newest, skips. Staging runs B. |
| Both at once | One push is rejected, retries against the newest trunk, then writes or skips. Staging runs B. |

Dev A lost nothing. Their login code is in staging, because B's image was
built from a `main` that already contained it. Both runs are green.

One case to know: if A is skipped as superseded and B then fails before
publishing (a Trivy `HIGH`, say), `deploy-staging` never runs for B and
staging stays on the previous SHA even though both pull requests merged
green. Fix `main` and let the next push deploy, or re-run Release on `main`.

Pushes to the shared GitOps repository are retried up to three times, since
many services commit to it.

## How the staging workflow works

Useful when a run does something you did not expect. It edits one line in
another repository; it never talks to the cluster.

1. **Validate.** `service_name` must be lowercase kebab-case and 63
   characters or fewer, because it becomes a namespace. `image_tag` must be
   a 40-character Git SHA; `latest` is rejected so "what is deployed" always
   has one answer.
2. **Check out `platform-gitops`** — not the service repo — into a `gitops/`
   directory, using `PLATFORM_GITOPS_TOKEN`. The default `GITHUB_TOKEN`
   cannot write to another repository.
3. **Install `yq`**, so the edit preserves formatting, key order, and
   comments in the values file.
4. **Update and push**, retrying up to three times:
   - Skip if this SHA is no longer the newest commit on `main` (above).
   - Re-read GitOps trunk (`fetch` and `reset --hard`) so each attempt edits
     the current state, not the clone from a minute ago.
   - Fail if the service's values file is missing. Provisioning is
     incomplete; the workflow will not create one and fake a deploy.
   - Set `.image.tag`, and exit early if staging already references that SHA,
     so a re-run makes no empty commit.
   - Commit with `Source: <repo>@<sha>` so GitOps history traces back to the
     service commit, then push.

Production promotion follows the same shape, with one extra gate: it reads
the staging values file first and refuses when staging is not running the
SHA being promoted.

## Inputs

Pass `image_tag` for production. Everything else has a platform default.

| Input | Default | Notes |
| --- | --- | --- |
| `service_name` | repository name | Must be lowercase kebab-case, 63 characters or fewer. |
| `image_tag` | `github.sha` (staging), required for production | 40-character Git SHA. `latest` is rejected. |
| `gitops_repository` | `developer-experience-DevEX-platform/platform-gitops` | |
| `gitops_branch` | `main` | |

## Related

- [Container release](container-release.md) — publishes the image this deploys
- [Platform](../platform.md) — the GitOps token
