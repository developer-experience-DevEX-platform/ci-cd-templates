# Platform

For people who maintain these templates and the GitHub / SonarCloud / AWS
org. Teams adopting CI can skip this page; use
[getting started](getting-started.md). Container publish variables are
summarized here so teams know they are provisioned, not hand-copied.

## Pinning

Documented callers use `@main`. That is the contract until tagged releases
exist. A service under test may pin a branch; switch it back to `@main`
before the service is considered done.

Dependabot updates GitHub Actions in this repository weekly.

## `SONAR_TOKEN`

Organization secret. Callers pass it with `secrets: inherit`. The reusable
workflows declare it as a required secret.

The token identity needs **Execute Analysis** and **Browse**. Analysis-only
is not enough: the quality-gate step calls the SonarCloud API and returns
403 without Browse.

Prefer a bot or org token over a personal token. Personal tokens expire.

## SonarCloud project

- Organization key: `developer-experience-devex-platform`
- Project key: GitHub repository name (`github.event.repository.name`)
- Host: `https://sonarcloud.io`

Assign the organization default **quality gate** to each project. A project
with no gate reports status `NONE` and the GitHub check cannot enforce
anything useful.

Do not import the project in the SonarCloud UI first if CI should
auto-provision it. Turning on Automatic Analysis fights the CI scan; leave
it off for these projects.

## GitHub app

Install the SonarQube Cloud GitHub app on the organization so pull requests
can get a Quality Gate comment (once PR analysis is on the plan). That is
an org install, not a workflow input.

## Developers vs CI

Developers log in with GitHub. They need Browse and See Source Code on the
projects they work on. They do not need Analyze.

The CI token is the identity that analyzes. Platform admins Administer the
org. Member sync with GitHub is a SonarCloud Team/Enterprise feature; on
Free, grant project permissions manually as needed.

## Temporary SonarQube trigger

Both `nodejs-ci.yml` and `python-ci.yml` use:

```yaml
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

Revert to `github.event_name == 'pull_request'` when PR analysis is available.
Callers do not change. Integration tests already allow `needs.sast.result ==
'skipped'` so PRs keep running while this exception is in place.

## Container release variables

Set per repository by Terraform (`service-container-release`), not by the
team:

- `AWS_REGION`
- `AWS_RELEASE_ROLE_ARN`
- `ECR_REPOSITORY`

The reusable workflow assumes the role with GitHub OIDC
(`id-token: write` on the publish job). ECR image tags are immutable.
Trust is repository- and branch-scoped (`refs/heads/main`).

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

## This repository's own CI

`self-check.yml` runs on pull requests and on pushes to `main`. Every other
workflow here is reusable and only runs in service repositories, so this is
the only place changes to the templates are exercised before teams get them.

It does two things:

- **`shellcheck`** over `scripts/` and `tests/`. Bash inside a workflow's
  `run:` block cannot be linted, which is the main reason
  `gitops-write-desired-state.sh` is a file rather than 45 lines of YAML.
- **`tests/gitops-write-desired-state.test.sh`**, which stands up a throwaway
  GitOps remote and walks both environments: a staging deploy, an idempotent
  re-run, a superseded SHA, a first promotion, a promotion staging does not
  back, a missing values file, and a bad environment. `gh` and `yq` are
  stubbed, so it needs no network and no credentials. Run it locally the same
  way CI does.

Changing the deploy logic without adding a case here means the next person
finds out in a service repository instead.
