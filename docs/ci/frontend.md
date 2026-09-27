# Frontend CI

Workflow: `.github/workflows/frontend-ci.yml`

React + Vite static sites. Same format, lint, unit, and dependency-scan
jobs as [Node.js CI](nodejs.md). No Dockerfile. On a pull request the
workflow then runs SonarQube and a production build so merge proves
`dist/` compiles.

The workflow does not run a browser or component test framework. Teams
add Playwright, Cypress, or nothing in their own repo or caller.

## Job graph

```text
push / pull_request:  format-lint  unit-tests  dependency-scan
pull_request only:                 sonarqube  ->  build
```

| Job | Feature branch | PR | `main` (via Release) | What it enforces |
| --- | --- | --- | --- | --- |
| Format & lint | yes | yes | yes | `format:check` and `lint` |
| Unit tests | yes | yes | yes | Tests pass and `coverage/lcov.info` exists |
| Dependency scan | yes | yes | yes | Trivy filesystem; `CRITICAL` and `HIGH` fail |
| SonarQube | no | yes | no | Quality gate after CI |
| Build | no | yes | no | `npm run build` writes `dist/` |

`main` runs only the three CI jobs (Release calls this workflow). Publish
is [static site release](../cd/static-site-release.md), not this file.

## Commands

```text
npm ci
npm run format:check
npm run lint
npm test -- --coverage
npm run build
```

The service must be an npm project with a `package-lock.json`.

- `format:check` exits non-zero when formatting drifts.
- `lint` exits non-zero on lint violations.
- `test` runs unit tests and, when passed `--coverage`, writes
  `coverage/lcov.info`.
- `build` writes `dist/`.

Yarn and pnpm are not supported. Swap Prettier, ESLint, or the unit-test
runner in `package.json`; the workflow does not change.

SonarQube reads `src` as sources and tests (`*.test.ts(x)` / `*.spec.ts(x)`),
and `coverage/lcov.info`. `main.tsx`, `main.ts`, and `index.ts` are
excluded from coverage.

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
    uses: developer-experience-DevEX-platform/ci-cd-templates/.github/workflows/frontend-ci.yml@v1.8.0
    permissions:
      contents: read
    secrets: inherit
```

Pin the first tag that includes this workflow (after `v1.8.0`). Do not
use `@main`.

If `release.yml` also calls this workflow, ignore `main` on the `push`
trigger as in the snippet above.

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `working_directory` | `.` | Directory containing `package.json`. |
| `node_version` | `24` | |

No `has_dockerfile` or integration-test inputs. There is no image and no
Compose job.

## Related

- [SonarQube](sonarqube.md)
- [Static site release](../cd/static-site-release.md)
