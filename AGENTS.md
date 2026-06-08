# HoverClick Codex Instructions

## Non-GUI Validation

- Build and verify must be non-GUI.
- Do not run `scripts/run-app.sh` automatically.
- Do not run the raw binary.
- Do not open browser or diagnostic UI.
- Do not use `sudo`.
- Do not use `tccutil reset`.
- Do not open Finder windows or tabs during automated validation.

## Project Identity And Permissions

- Do not change the app name unless explicitly requested.
- Do not change the bundle identifier unless explicitly requested.
- Do not change the signing identity unless explicitly requested.
- Do not change Info.plist identity fields unless explicitly requested.
- Do not change the Accessibility/TCC flow unless explicitly requested.

## Auto-Save Workflow

After a successful Codex task, if files changed intentionally, run:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/save-work.sh "Short task description"
```

The save workflow builds the app, verifies codesigning, stages safe project files, commits, and pushes to `origin/main`.

- Do not push if build or verify fails.
- Do not commit generated artifacts such as `HoverClick.app/`, `DerivedData/`, `build/`, `logs/`, or `dist/*.dmg`.
- Report the commit hash and push result.
