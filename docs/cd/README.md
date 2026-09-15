# CD

CD starts after CI says the change is safe to merge. These workflows build,
publish, and deploy. They do not format, lint, or run unit tests.

| Workflow | Status | Docs |
| --- | --- | --- |
| Container release | Available | [container-release.md](container-release.md) |
| Kubernetes GitOps | Exists, not reviewed | Later |
| Production promotion | Exists, not reviewed | Later |
| Node.js Lambda | Exists, not reviewed | Later |

Lambda services do not call container release. They have their own package /
release / staging path.
