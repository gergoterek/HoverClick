# Project State

Last updated: 2026-08-30

Short, current source of truth. Update this file at the end of every work cycle.
Everything historical lives in `docs/CURRENT_STATE.md` and `docs/DECISIONS.md`.

---

## Baseline

| | |
|---|---|
| Released version | `v1.2.1` / build `43` |
| `main` commit | `f24f506b3247bafcf00bd1d9610870a299bebdf8` |
| Branch tip in use | `fix/single-window-focus` @ `93ae113` |
| Bundle ID | `com.gergoterek.HoverClick` |
| Project path | `/Users/terekgergo/Projects/HoverClick` |
| Signing identity | **None available.** `security find-identity -v -p codesigning` returns `0 valid identities found`. |
| Sparkle EdDSA private key | **Not available on this machine.** |
| Build status | Compiles clean on macOS 26.6.2 / clang 21. Local builds are not signed with a certificate and are not distributable. |

---

## Machine change — 2026-08-27

The project moved to a new machine after the previous one was compromised. The repository
itself is intact: the working tree was reconstructed from a fresh clone of
`github.com/gergoterek/HoverClick`, and every recovered source file matched its committed
blob exactly. No source work was lost.

Two credentials did not survive and cannot be recovered from backup:

- the `Apple Development` signing certificate that the Makefile and `scripts/build-app.sh`
  still name
- the Sparkle EdDSA private key matching `Info.plist:SUPublicEDKey`

See `docs/DECISIONS.md`, entry "Signing certificate and Sparkle private key are gone", for
what this blocks and what is still undecided.

**Documentation not yet corrected.** `CLAUDE.md:60`, `docs/PERMISSIONS.md`,
`docs/TEST_MATRIX.md`, `docs/RELEASE.md`, `docs/RELEASE_TEST.md`, `docs/CURRENT_STATE.md`
and `docs/UPDATER_DESIGN.md` still describe the old certificate as present and required.
Those statements are false on this machine. Do not trust them; run
`security find-identity -v -p codesigning` instead.

`PROJECT_DIR` is hardcoded to the old machine's path in the `Makefile` and in seven
scripts. `scripts/ci-safety-check.sh` and `scripts/source-only-check.sh` are unaffected
because they derive the path from their own location.

---

## Work queue

Only one branch is worked on at a time. Finish or park the top item before starting the next.

| # | Branch | State |
|---|---|---|
| 1 | `fix/single-window-focus` | **Done and verified at runtime.** Not merged to `main`. |
| 2 | `feature/menu-help-tooltips` | Not started. Replace the `Guide` submenu with hover tooltips. **Blocked on a decision — see below.** |

### Queued: Guide submenu → tooltips

The user wants the `Guide` submenu (`HoverClick.mm:1512`) removed and replaced by hover
tooltips on the menu rows.

This conflicts with a decision already made and recorded. Native in-menu tooltips were
implemented twice and reverted twice (`4fe9e91` / `135a786`, `8103ab8`), and the `Guide`
submenu is their deliberate replacement. Making tooltips visible requires a hover timer, a
global monitor, or a floating window — all forbidden by `CLAUDE.md`.

Read `docs/DECISIONS.md`, entry "In-menu tooltips were tried twice and reverted twice",
before planning this. The first step is a decision, not an implementation.

---

## Closed: multi-window focus bug

**Bug:** clicking one visible background window brought other windows of the same
application forward with it.

**Fix:** `93ae113` — `kAXFrontmostAttribute` is no longer set on the application element.
That attribute applies to the whole application and cannot distinguish between its windows.
Focus is now directed at the clicked window alone, through `kAXFocusedWindowAttribute` on
the application element plus `kAXRaiseAction`, `kAXMainAttribute` and `kAXFocusedAttribute`
on the window itself.

The same commit removed the four-mode `focusExperimentMode` scaffolding added by `f88d0bb`.
A stored mode survived relaunches and silently changed focus behavior, which is not
acceptable outside an investigation.

**Runtime verification, 2026-08-30:** two Chrome windows, a third application in front,
click on the visible edge of the background Chrome window. Only the clicked window came
forward. Tested on macOS 26.6.2 against a locally built bundle from `93ae113`.

This answers the question left open on 2026-08-03 about whether public Accessibility APIs
can raise a single window. They can. Recorded in `docs/DECISIONS.md`.

**Still open:** verification inside `focusTargetApp:` compares only
`frontAfter.processIdentifier == targetPid`, which cannot observe which window holds focus.
`93ae113` added a verbose-only readback of `kAXFocusedWindowAttribute` next to it, but the
pass/fail decision still rests on the process-level check. AX operation errors are logged
and execution continues rather than counting as failures.

---

## Development mode

Local build and runtime test are possible and were used to verify the focus fix.
Certificate-based signing is not, until a signing decision is made.

Allowed:

- `scripts/source-only-check.sh` — static gate, run first, unaffected by the path problem
- local compile and launch of a locally built bundle
- commit and push a feature branch when asked

Out of scope for this cycle:

- merging to `main`, tagging, DMG packaging, appcast, GitHub Release
- `scripts/checkpoint.sh` — it commits and pushes in the same step as the build
- modularizing `HoverClick.mm`
- branch cleanup

---

## Known follow-up work

Keep each of these on its own branch.

- Replace the hardcoded `PROJECT_DIR` in the `Makefile` and the seven affected scripts with
  a path derived from the script location, as `ci-safety-check.sh` already does.
- Correct every document that still claims the old signing certificate is present.
- Decide the signing strategy for local development and for release.
- Decide what happens to the Sparkle update channel now that the private key is gone.
  Existing `v1.2.1` installations cannot be served an update signed by any new key.
- Make `focusTargetApp:` verification check the focused window, not only the frontmost
  process, and treat AX operation errors as failures.
- `HoverClick.mm` is a single ~4,900-line file. Extract `FocusController` now that the
  focus behavior is correct.
- CI runs static safety checks only, no build.
- Static analyzer reports two nullability issues, including a nil SF Symbol name on the
  empty Excluded Apps row.
- Verbose diagnostics log AX element and window titles as `%{public}` (`HoverClick.mm:881`).
- Sparkle is pinned to 2.9.3 by hash; upstream is 2.9.4.
- 67 remote branches. Do not clean them up as a side task.
