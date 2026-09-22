# SonarQube

The SonarQube job is the quality gate between unit tests and integration
tests. Callers do not configure a host URL or project key; the reusable
workflow does.

## What the service must do

1. Pass `secrets: inherit` on the caller so org secret `SONAR_TOKEN` is
   available.
2. Produce the coverage file the language contract names:
   - Node.js: `coverage/lcov.info`
   - Python: `coverage.xml`

SonarCloud will not auto-create a project from a pull-request scan, even
when the token has **Create Projects**. The job posts once to
`/api/projects/create`, then analyzes.

The SonarCloud organization is not hardcoded. The job uses
`vars.SONAR_ORGANIZATION` when that GitHub org or repo variable is set.
Otherwise it uses the lowercase GitHub organization login. Each GitHub
org that adopts the template sets its own `SONAR_TOKEN` and, if the
SonarCloud org key differs from the GitHub login, `SONAR_ORGANIZATION`.

The project key is `{github-org}_{repo}` in lowercase, for example
`developer-experience-devex-platform_payment-api`. SonarCloud keys are
global, so a bare `payment-api` can already belong to an unrelated org.
"Already exists" is success only when search finds that key in the
resolved SonarCloud organization.

The org `SONAR_TOKEN` needs **Create Projects**, **Execute Analysis**, and
**Browse**.

## When it runs

On **pull requests** only, after format, lint, unit tests, and the
dependency scan pass. See [overview](../overview.md).

A failed gate fails the GitHub job. Integration tests do not run unless
SonarQube succeeded.

## Reading a failure

1. Open the **SonarQube** check on the commit (or the PR comment when PR
   analysis is enabled).
2. Follow the SonarCloud link. The gate lists which condition failed
   (coverage on new code, issues, and so on).
3. Fix the code or tests in the service. Do not skip the job in the caller.

Missing coverage usually means `npm test -- --coverage` / `make test` did not
write the file the workflow uploads. The upload step fails with
`if-no-files-found: error` before SonarQube runs.

## What teams do not configure

Do not create a SonarCloud user per developer for CI. Do not put a token in
the service repo. Do not turn on Automatic Analysis for a project that uses
this workflow; CI already scans.

Org token permissions, the GitHub app, and the default quality gate are
[platform](../platform.md) work.
