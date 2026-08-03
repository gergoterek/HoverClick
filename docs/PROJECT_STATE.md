# Project State

Last updated: 2026-08-03

Short, current source of truth. Update this file at the end of every work cycle.
Everything historical lives in `docs/CURRENT_STATE.md` and `docs/DECISIONS.md`.

---

## Baseline

| | |
|---|---|
| Released version | `v1.2.1` / build `43` |
| `main` commit | `f24f506b3247bafcf00bd1d9610870a299bebdf8` |
| Bundle ID | `com.gergoterek.HoverClick` |
| Signing identity | `Apple Development: rizsutt@gmail.com (MVQ5PX4679)` — **valid until 2027-05-06** |
| Build status | Working. `make check-signing` passes, `codesign --verify` on the shipped app returns clean. |

---

## Active task

**Bug: clicking one visible background window brings other windows of the same app forward.**

Reproduced by the user with multiple Chrome windows and multiple TextEdit windows.
Not app-specific. Stage Manager, Rectangle and BetterTouchTool were all off during the test.

Current focus sequence in `focusTargetApp:` — `HoverClick.mm:4586`:

| Line | Call | Scope |
|---|---|---|
| 4652 | `activateWithOptions:NSApplicationActivateIgnoringOtherApps` | **whole app** |
| 4677 | `kAXFrontmostAttribute = true` on the app element | **whole app** |
| 4679 | `kAXFocusedWindowAttribute = targetWindow` on the app element | app element |
| 4686 | `kAXRaiseAction` on the target window | window |
| 4691–4692 | `kAXMainAttribute`, `kAXFocusedAttribute` on the target window | window |
| 4710 | `frontAfter.processIdentifier == targetPid` | **process only** |

Two app-wide operations run *before* the target window is raised. Those are the primary
suspects.

The verification at line 4710 is a second, separate defect: it only checks that the target
**process** became frontmost. It cannot detect the reported bug at all, so the current
diagnostics will report `success` for exactly the behavior being complained about.

### Target branch

`fix/single-window-focus`, branched from `main` @ `f24f506`.

### What the fix must do

- Raise only the clicked `AXUIElement` window.
- Leave other windows of the same process where they are in the z-order.
- Keep the original event pass-through path untouched.
- Extend verification to check the app's `kAXFocusedWindowAttribute` equals the target
  window, not only that the process is frontmost.
- Count AX operation errors as real failures instead of logging and continuing.

### Open technical question — resolve before implementing

It is not established that public Accessibility APIs alone can raise one window of a
background app above another app's window without activating the app. Third-party window
managers use private SkyLight APIs for this. If the AX-only path fails, a fallback decision
is needed before more code is written. This is a hypothesis, not a tested fact.

---

## Development mode

**Local build and runtime test are allowed and expected.** The signing identity works, so
there is no reason to fix a window z-order bug blind.

Allowed:

- `scripts/source-only-check.sh` — static gate, run first
- `scripts/build-app.sh` — compile + sign
- `scripts/verify-app.sh`, `scripts/run-app.sh` — verify and launch locally
- commit and push a feature branch to GitHub when asked

Out of scope for this cycle:

- renewing or replacing the signing certificate — nothing is wrong with it
- merging to `main`, tagging, DMG packaging, appcast, GitHub Release
- `scripts/checkpoint.sh` — it commits and pushes in the same step as the build
- modularizing `HoverClick.mm`
- branch cleanup

**Endpoint of this cycle:** a feature branch on GitHub, runtime-tested locally against
Chrome and TextEdit, not merged.

---

## Known follow-up work

Keep each of these on its own branch, after the focus bug is closed.

- `README.md:15` says `v1.2.0` / build `42`; the app is `v1.2.1` / build `43`.
- `HoverClick.mm` is a single ~4,900-line file. Extract `FocusController` once the focus
  behavior is correct and covered.
- CI runs static safety checks only, no build.
- Static analyzer reports two nullability issues, including a nil SF Symbol name on the
  empty Excluded Apps row.
- Verbose diagnostics log AX element and window titles as `%{public}` (`HoverClick.mm:881`).
- Sparkle is pinned to 2.9.3 by hash; upstream is 2.9.4.
- 78 local / 66 remote branches; repo is 165 MB (80 MB `dist`, 45 MB `tmp`).
