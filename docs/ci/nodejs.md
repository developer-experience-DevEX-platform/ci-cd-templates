# Node.js CI

Workflow: `.github/workflows/nodejs-ci.yml`

Same [job graph](../overview.md) as every other language CI. This page is the
npm contract and the caller you paste.

## Commands

```text
npm ci
npm run format:check
npm run lint
npm test -- --coverage
npm run test:integration      only when has_integration_tests is true
```

The service must be an npm project with a `package-lock.json`. Scripts must
meet this contract:

- `format:check` exits non-zero when formatting drifts.
- `lint` exits non-zero on lint violations.
- `test` runs unit tests and, when passed `--coverage`, writes
  `coverage/lcov.info`.
- `test:integration` starts the suite's own dependencies and tests how
  components work together. Required only when `has_integration_tests` is
  `true`. Docker must be available; it already is on `ubuntu-latest`.

The golden path ships these scripts backed by Prettier, ESLint, and Jest. Swap
a tool in `package.json`; the workflow does not change. Yarn and pnpm are not
supported.

SonarQube reads `src` as sources, `test` as tests, and
`coverage/lcov.info`. `**/index.ts` is excluded from coverage so boot files
do not fail the gate.

## Caller

```yaml
name: CI

on:
  push:
    branches-ignore:
      - main
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: true

jobs:
  ci:
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/nodejs-ci.yml@v1.7.0
    permissions:
      contents: read
    secrets: inherit
    with:
      has_integration_tests: true
```

Lambda services set `has_dockerfile: false`.

If `release.yml` also calls this workflow, ignore `main` on the `push`
trigger as in the snippet above. Release runs CI on merge, so a second CI
workflow on `main` is duplicate work. That `ci` job uses the same
permissions and `secrets: inherit`. Do not add `id-token: write` there;
that is only for [container release](../cd/container-release.md).

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Directory containing `package.json`. |
| `node_version` | `24` | |
| `has_dockerfile` | `true` | Set to `false` for Lambda. |
| `dockerfile_path` | `./Dockerfile` | Relative to the repository root. |
| `has_integration_tests` | `false` | Set to `true` for the platform job. Leave `false` to skip it or to own a separate job in the caller. |
| `integration_test_vars` | `{}` | JSON object of non-secret environment variables. |

Shared input meaning: [CI standard](README.md).

## Related

- [Integration tests](integration-tests.md)
- [SonarQube](sonarqube.md)
