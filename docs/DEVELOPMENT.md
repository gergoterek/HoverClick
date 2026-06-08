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
