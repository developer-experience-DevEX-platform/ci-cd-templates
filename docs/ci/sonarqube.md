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

The first successful analysis creates the SonarCloud project when
auto-provisioning is on. The project key is the GitHub repository name.
Organization: `developer-experience-devex-platform`.

## When it runs

Today it runs on **push to `main`** because SonarCloud Free analyzes the
default branch only. The intended trigger is pull requests. See
[overview](../overview.md).

A failed gate fails the GitHub job. Integration tests do not run unless
SonarQube succeeded or was skipped.

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
