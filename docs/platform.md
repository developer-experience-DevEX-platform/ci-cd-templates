# Platform

For people who maintain these templates and the GitHub / SonarCloud / AWS
org. Teams adopting CI can skip this page; use
[getting started](getting-started.md). Container publish variables are
summarized here so teams know they are provisioned, not hand-copied.

## Pinning

Documented callers pin a git tag. The current release is `@v1.5.0`.
That version covers Node.js CI, Python CI, container release,
Kubernetes GitOps, and TechDocs publish. Lambda workflows are
not in this release; do not call them from Backstage.

```yaml
uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-ci.yml@v1.5.0
uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/techdocs-publish.yml@v1.5.0
```

Do not follow `@main` for those workflows. A service under test
may pin a branch; switch it back to the release tag before the service
is considered done.

Terraform modules pin git tags the same way. CI/CD used to float on
`@main`; that ends at `v1.0.0`.

To cut a new version:

1. Change a reviewed workflow on `main`.
2. Tag `vX.Y.Z` on that commit.
3. Bump the Backstage skeleton and every documented caller together.

Dependabot updates GitHub Actions in this repository weekly. That does
not bump caller pins.

## `SONAR_TOKEN`

Organization secret on **each** GitHub organization that uses these
templates. Callers pass it with `secrets: inherit`. The reusable
workflows declare it as a required secret.

The token identity needs **Create Projects**, **Execute Analysis**, and
**Browse**. Create Projects is required for the PR job's create call.
Analysis-only is not enough: the quality-gate step calls the SonarCloud
API and returns 403 without Browse.

Prefer a bot or org token over a personal token. Personal tokens expire.

## SonarCloud project

- Organization key: `vars.SONAR_ORGANIZATION`, or the lowercase GitHub
  organization login when that variable is empty.
- Project key: `{github-org}_{repo}` in lowercase
  (`developer-experience-devex-platform_payment-api`). SonarCloud keys
  are global; the GitHub org prefix keeps them specific to the adopting
  GitHub organization.
- Host: `https://sonarcloud.io`

Set `SONAR_ORGANIZATION` as a GitHub **organization** variable when the
SonarCloud org key is not the lowercase GitHub login. Do not bake a
single SonarCloud org into the reusable workflow.

Assign the organization default **quality gate** to each project. A project
with no gate reports status `NONE` and the GitHub check cannot enforce
anything useful.

Do not import the project in the SonarCloud UI first if CI should
auto-provision it. Turning on Automatic Analysis fights the CI scan; leave
it off for these projects.

## GitHub app

Install the SonarQube Cloud GitHub app on the organization so pull requests
get a Quality Gate comment. That is an org install, not a workflow input.

## Developers vs CI

Developers log in with GitHub. They need Browse and See Source Code on the
projects they work on. They do not need Analyze.

The CI token is the identity that analyzes. Platform admins Administer the
org. Member sync with GitHub is a SonarCloud Team/Enterprise feature; on
Free, grant project permissions manually as needed.

## Container release variables

Set per repository by Terraform (`service-container-release`), not by the
team:

- `AWS_REGION`
- `AWS_RELEASE_ROLE_ARN`
- `ECR_REPOSITORY`
- `TECHDOCS_S3_BUCKET`

The reusable workflows assume the role with GitHub OIDC
(`id-token: write` on the publish jobs). ECR image tags are immutable.
TechDocs writes `default/component/<service>/` on the shared bucket.
Trust is repository- and branch-scoped (`refs/heads/main`). If container
release is invoked with empty AWS variables, that job fails. TechDocs
publish is skipped by the caller until `TECHDOCS_S3_BUCKET` exists, then
fails if the variables are empty. Do not skip inside the reusable
workflows.

The template publishes only on `push` to `main`. PR callers must keep
`if: github.event_name == 'pull_request'` so `ci.yml` does not publish on
merge. Details: [container release](cd/container-release.md).

## `PLATFORM_GITOPS_TOKEN`

Organization secret. Callers pass it with `secrets: inherit`. Scope it to
`platform-gitops` with contents read/write; the GitOps workflows commit the
released Git SHA there.

Both GitOps workflows default to
`developer-experience-DevEX-platform/platform-gitops` on `main`. Teams do
not pass those.

Production promotion runs in the GitHub `production` environment, so
reviewers configured there gate it. Backstage creates the staging and
production values files; the workflow fails when one is missing instead of
creating it. Details: [Kubernetes GitOps](cd/kubernetes-gitops.md).
