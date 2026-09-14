# Go CI

Not shipped. `.github/workflows/go-ci.yml` is a placeholder.

When it exists, it will use the same [CI standard](README.md): parallel
format, lint, unit tests, and dependency scan on every push and pull request;
SonarQube and hermetic integration tests after that.

Do not call this workflow yet. Use [Node.js](nodejs.md) or [Python](python.md)
if you are adopting CI now.
