# HoverClick

macOS menu bar utility. Clicking a background window focuses **that window** before the
original click is delivered. Objective-C++ / AppKit / Accessibility API.

- Bundle ID: `com.gergoterek.HoverClick`
- Released: `v1.2.1` / build `43` (main @ `f24f506`)
- Main source: `HoverClick.mm` (~4,900 lines, single file)
- Minimum macOS: 12.0

Formerly named PreClickFocus. Some old branches and certificates still use that name.

---

## Where truth lives

Read in this order. Stop at the first file that answers your question.

| File | What it holds |
|---|---|
| This file | Rules that never change |
| `docs/PROJECT_STATE.md` | What is being worked on right now |
| `docs/DECISIONS.md` | Why past choices were made, what was tried and rejected |
| `docs/CHAT_WORKFLOW.md` | How the two working chats hand off to each other |
| `docs/CURRENT_STATE.md` | Historical engineering log — large, load a section only |

Do not load `docs/CURRENT_STATE.md`, `docs/TEST_MATRIX.md`, or the `V1.*` planning docs
at startup. They are 60–90 KB each and will fill the context window.

---

## Hard invariants — never break these

These are enforced by `scripts/ci-safety-check.sh`. Breaking one is a release blocker,
not a style issue.

1. **Event tap mask stays left + right mouse-down only.**
   No `kCGEventMouseMoved`, no `kCGEventScrollWheel`, no mouse-up, no drag, no keyboard.
2. **The original event is returned unchanged** from the tap callback.
3. **No synthetic events.** These identifiers must never appear in `HoverClick.mm`:
   `CGEventPost`, `CGEventCreateMouseEvent`, `CGDisplayMoveCursorToPoint`,
   `CGWarpMouseCursorPosition`, `CGAssociateMouseAndMouseCursorPosition`.
4. **No cursor movement.** Ever.
5. **No AutoRaise behavior.** Hovering must never focus anything. Focus only follows a click.
6. **No event replay or delayed click delivery.**

If a task appears to require breaking one of these, stop and report it instead.

---

## Commands

```zsh
scripts/source-only-check.sh      # static gate: whitespace, safety suite, shell + ObjC syntax
scripts/build-app.sh              # compile + codesign into HoverClick.app
scripts/verify-app.sh             # codesign verification
scripts/run-app.sh                # launch the signed app
```

Signing identity `Apple Development: rizsutt@gmail.com (MVQ5PX4679)` is valid until
**2027-05-06** and is required by the Makefile. Do not change it, do not replace the
certificate, do not touch the bundle identifier.

**Never run:** `sudo`, `tccutil reset`, raw binary execution from `HoverClick.app/Contents/MacOS/`.

`scripts/checkpoint.sh` builds, signs, commits **and pushes** in one shot. Use explicit
git commands instead so each step is visible.

---

## Git policy

- Branch from `main`. One branch per task.
- No force push, no history rewrite, no branch deletion.
- No merge to `main`, no tag, no DMG packaging, no appcast edit unless explicitly asked.
- Commit and push only when the user asks for it in the current turn.

The repository has 78 local and 66 remote branches. Do not clean them up as a side task.

---

## Working rules

- Verify claims against the repository before stating them. Two earlier audits reported
  facts that were not true on this machine.
- Separate **verified** from **inferred** in every report.
- A passing static check never proves runtime behavior. Say which one you actually have.
- Do not modularize `HoverClick.mm` while a behavior fix is in progress.
- Reply to the user in Hungarian. Keep code, commits and docs in English.
