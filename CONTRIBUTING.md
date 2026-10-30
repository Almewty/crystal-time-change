# Contributing

## Commit and release contract

Use **Conventional Commits** for every new commit and squash-merge title:

- `feat(clock): add a setting` → minor release.
- `fix(clock): correct a setting` or `perf(clock): reduce reads` → patch release.
- `feat(clock)!: change the saved format` or a `BREAKING CHANGE:` footer → major release.
- `docs:`, `test:`, `ci:`, `chore:`, and ordinary `refactor:` commits do not release by themselves.

Keep commits focused and push working increments regularly. Do not rewrite the
original pre-convention history. Do not hand-edit versions or create release tags.
There are no published tags at bootstrap, so the first release is `v1.0.0`;
subsequent versions come from commits since the last release tag.

On every push to `main`, **Verify and release** calls the shared test workflow.
Only after all tests pass does semantic-release analyze commits, generate notes,
build the ZIP and checksum, push `v<version>`, and publish a GitHub Release.
If there is no release-worthy commit, it publishes nothing. Manual workflow runs
use the same rules; they do not force a version or bypass tests.

The release job has only `contents: write` and uses GitHub's automatic token.
No deploy-key secret, PAT, npm token, npm publication, or release-bot commits are
required. If repository rules block tag creation, grant the GitHub Actions app
permission to create the release tags; do not disable tests to work around it.

## Artifacts

Every release attaches:

- `crystal_time_change-<version>.zip` with `manifest.json` at the archive root.
- `crystal_time_change-<version>.zip.sha256` for `sha256sum -c` verification.

`tools/package.py --version <version>` stamps only the archived manifest. The
checked-in manifest's `1.0.0` is a local-build baseline, not the published version
authority. This avoids bot commits, protection-rule bypasses and release loops.
The app reads the correct semantic-release version from the release ZIP.

Do not manually create an empty GitHub Release expecting it to trigger a build:
semantic-release owns the release and uploads its artifacts in the same job.
This also avoids GitHub's restriction on workflows triggered by events created
with `GITHUB_TOKEN`.

## Checks

Requires Node.js 24.10+ (CI uses Node 24 LTS), Python 3.10+, and LuaJIT.

```sh
npm ci --ignore-scripts
npm test
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/package.py --version 1.2.3
```

Run the engine integration suite as described in README.md as well. Package tests
use temporary directories and verify root layout, stamping, unchanged sources,
checksums and invalid-version rejection. Node tests exercise the real commit
analyzer and release-notes generator, including both breaking-change forms.

Dependencies are exact-version locked. The Conventional Commits preset stays on
9.x because semantic-release 25's writer does not support preset 10.x. At setup,
`npm audit` reported two advisories in the **unused npm publishing plugin's bundled
npm dependencies** (`ip-address` and `undici`). This project's explicit plugin list
does not invoke that npm plugin, and none of this tooling ships in the mod ZIP.
Recheck upstream updates rather than blindly overriding bundled dependencies.
