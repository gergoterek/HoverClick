# Development Workflow

## Active Mode: Two Chats, Local Build

Feature work runs in two Claude Code chats — `BUILD` and `REVIEW`. See
`docs/CHAT_WORKFLOW.md` for the roles and `docs/chat-starters/` for the prompts.

Start a chat by opening Claude Code in the repository root. `CLAUDE.md` loads
automatically; the starter prompt only adds the role. Read `docs/PROJECT_STATE.md` for the
current task. Do not load `docs/CURRENT_STATE.md` or `docs/TEST_MATRIX.md` at startup.

Run the static gate before every build:

```zsh
scripts/source-only-check.sh
```

It runs Git whitespace checks, the static safety suite, shell syntax coverage, and a
syntax-only source check when the pinned Sparkle framework cache is available. It does not
build, sign, verify, launch, package, publish, or change Git state.

Then build and test locally:

```zsh
scripts/build-app.sh
scripts/verify-app.sh
scripts/run-app.sh
```

Signing uses the identity named by `SIGNING_IDENTITY` in the `Makefile` (see `CLAUDE.md`,
"Commands", and `docs/DECISIONS.md` for its history). Verify behavior changes at runtime
whenever that identity is in the login keychain. A static PASS never proves runtime behavior:
report which one you have.

Do not use `scripts/checkpoint.sh`: it builds, signs, commits and pushes as one operation.
Use explicit Git commands so each step is visible, and follow the Git policy in `CLAUDE.md`.

## Continuous Integration

CI currently runs static safety checks only. The workflow checks repository text, stable event tap scope, the bundle identifier, script syntax, generated artifact tracking, and documentation safety wording.

CI does not build, sign, package, launch, notarize, use Apple credentials, or change macOS permissions. Local signed build and verification work remains handled by the local project scripts.

Manual release and performance validation is local. Use `docs/RELEASE_TEST.md` before tagging or publishing a source-first release candidate.

## Internal DMG Packaging

Create an internal/test signed DMG with:

```zsh
scripts/package-dmg.sh
```

The packaging script builds HoverClick, verifies codesigning, copies the signed `HoverClick.app` bundle into a temporary staging directory, adds an `Applications` symlink, creates a compressed read-only DMG under `dist/`, and verifies the image with non-GUI command-line checks.

This workflow signs with the same identity as `scripts/build-app.sh`. It is for local/internal testing only; it is not Developer ID signed, not notarized, and not a polished public installer.

For the public distribution model see `docs/RELEASE.md`; `README.md` names the latest public release.

Generated DMG artifacts are ignored and should not be committed.
