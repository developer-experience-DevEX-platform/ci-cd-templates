# CD

CD starts after CI says the change is safe to merge. These workflows build,
publish, and deploy. They do not format, lint, or run unit tests.

```text
push to main:   ci  ->  container-release  ->  gitops staging
                ci  ->  static-site-release
                ci  ->  techdocs-publish
manual:         gitops production promotion
```

| Workflow | Status | Docs |
| --- | --- | --- |
| Container release | Available | [container-release.md](container-release.md) |
| Static site release | Available | [static-site-release.md](static-site-release.md) |
| Kubernetes GitOps (staging + production) | Available | [kubernetes-gitops.md](kubernetes-gitops.md) |
| TechDocs publish | Available | [techdocs.md](techdocs.md) |
| Node.js Lambda | Exists, not reviewed | Later |

A service repo needs two files: `release.yml` (push to `main`) and
`promote-production.yml` (manual). Both are thin callers with
`secrets: inherit`.

Lambda services do not call container release or GitOps. They have their own
package / release / staging path.

Static sites do not call container release or GitOps. They call
[static site release](static-site-release.md) when `STATIC_SITE_BUCKET` is
set. One bucket and one CloudFront in v1.
