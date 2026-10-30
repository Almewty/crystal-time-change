# Development rules

- Follow CONTRIBUTING.md. Every new commit and squash title uses Conventional
  Commits; make focused commits and push working increments regularly.
- semantic-release owns versions/tags/releases. Use feat/fix/perf and explicit
  breaking-change markers accurately; do not rewrite existing history or create
  manual version-bump commits.
- Write a failing regression/behavior test before changing executable code.
  Run Node release-tool tests, Python package tests, and the pinned Gen1Recomp
  v0.3.98 engine tests before pushing release-worthy changes.
- Keep runtime changes Crystal-only and never operate on a stale game.save at
  the title menu. Keep credentials, tests, build tools and ROM assets out of ZIPs.
- Main pushes run verification then release automatically when warranted.
  Read back CI/release state and published assets before claiming success.
