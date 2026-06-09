# Development Workflow

`main` is the stable baseline. Development work should happen on task branches and should be merged back to `main` only after review and manual approval.

Use the checkpoint script after a successful change:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/checkpoint.sh --branch "work/<short-task-name>" "Short commit message"
```

If no branch is provided while on `main`, the script creates a task branch named:

```text
work/<slug>-YYYYMMDD-HHMMSS
```

The checkpoint workflow:

- builds the app
- verifies codesigning
- stages intentional project source, documentation, and script changes
- commits staged changes when present
- pushes the task branch with `git push -u origin HEAD`

The checkpoint script refuses generated artifacts such as `HoverClick.app/`, `DerivedData/`, `build/`, `logs/`, and `dist/*.dmg`.

Do not merge task branches into `main` automatically.

## Continuous Integration

CI currently runs static safety checks only. The workflow checks repository text, stable event tap scope, the bundle identifier, script syntax, generated artifact tracking, and documentation safety wording.

CI does not build, sign, package, launch, notarize, use Apple credentials, or change macOS permissions. Local signed build and verification work remains handled by the local project scripts.

## Internal DMG Packaging

Create an internal/test Apple Development signed DMG with:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh
```

The packaging script builds HoverClick, verifies codesigning, copies the signed `HoverClick.app` bundle into a temporary staging directory, adds an `Applications` symlink, creates a compressed read-only DMG under `dist/`, and verifies the image with non-GUI command-line checks.

This workflow keeps the existing Apple Development signing identity. It is for local/internal testing only; it is not Developer ID signed, not notarized, and not a polished public installer.

The current public distribution path is GitHub/source-first: clone the repository, build locally from source, run the signed `.app` bundle, and grant Accessibility permission through System Settings. Apple Developer Program membership is not required for that current path.

Generated DMG artifacts are ignored and should not be committed.
