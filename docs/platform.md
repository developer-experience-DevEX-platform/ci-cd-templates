# Platform

For people who maintain these templates and the GitHub / SonarCloud org.
Teams adopting CI can skip this page; use [getting started](getting-started.md).

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
