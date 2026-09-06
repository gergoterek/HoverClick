# Project State

Last updated: 2026-09-06

Short, current source of truth. Update this file at the end of every work cycle.
Everything historical lives in `docs/CURRENT_STATE.md` and `docs/DECISIONS.md`.

---

## Baseline

| | |
|---|---|
| Released version | `v1.2.1` / build `43` |
| `main` commit | `f24f506b3247bafcf00bd1d9610870a299bebdf8` |
| Branch tip in use | `fix/single-window-focus` @ `c700de2` |
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
| 1 | `fix/single-window-focus` | **Two fixes in, both verified at runtime.** Not merged to `main`. |
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

**First fix:** `93ae113` stopped setting `kAXFrontmostAttribute` on the application element.
That attribute applies to the whole application and cannot distinguish between its windows.
The same commit removed the four-mode `focusExperimentMode` scaffolding added by `f88d0bb`,
because a stored mode survived relaunches and silently changed focus behavior.

**Second fix:** `c700de2` reordered `focusTargetApp:`. The first fix was necessary and not
sufficient. `-activateWithOptions:` carries the application's own main window forward, and
that main window was still the sibling the user had focused earlier, so activating before
the window-level operations dragged the sibling in front of whatever was on top. Focus now
goes to the clicked window first, through `kAXFocusedWindowAttribute` on the application
element plus `kAXRaiseAction`, `kAXMainAttribute` and `kAXFocusedAttribute` on the window,
and the application is activated only afterwards.

**Runtime verification, 2026-09-06:** macOS 26.6.2, locally built bundle from `c700de2`, two
Chrome windows with a third application in front. On `click #37` the clicked window was
raised, the verbose readback reported `match=YES`, and the CGWindowList z-order right after
the click was clicked Chrome window, third application, sibling Chrome window, so the
sibling kept its place. The 2026-08-30 test of `93ae113` passed as well, but it did not
separate the clicked window from the application's main window, which is why it missed this
case.

**Not attributable:** one earlier sample in the same session (`click #34`) ended with both
Chrome windows above the front application. There the clicked window was already Chrome's
main window, and a second user click landed one second later, inside the resolution of the
window-order watcher. Re-measure before calling that a residual bug.

**Still open:** verification inside `focusTargetApp:` compares only
`frontAfter.processIdentifier == targetPid`, which cannot observe which window holds focus.
The verbose-only readback of `kAXFocusedWindowAttribute` runs next to it, but the pass/fail
decision still rests on the process-level check. AX operation errors are logged and
execution continues rather than counting as failures.

---

## Development mode

Local build and runtime test are possible and were used to verify the focus fix.
Certificate-based signing is not, until a signing decision is made.

A local rebuild changes the bundle's code hash, so macOS drops its Accessibility permission.
After a rebuild, re-grant Accessibility in System Settings and then relaunch HoverClick: a
process that is already running keeps the denied state even after the toggle is set, and its
log keeps reporting `accessibility trusted = NO`.

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
- Re-measure the multi-window focus path with a sub-second window-order log, to settle the
  one 2026-09-06 sample that could not be attributed. If a sibling window does come forward
  again, the next lever is dropping `-activateWithOptions:` and letting the user's own click
  activate the application.
- `HoverClick.mm` is a single ~4,900-line file. Extract `FocusController` now that the
  focus behavior is correct.
- CI runs static safety checks only, no build.
- Static analyzer reports two nullability issues, including a nil SF Symbol name on the
  empty Excluded Apps row.
- Verbose diagnostics log AX element and window titles as `%{public}` (`HoverClick.mm:881`).
- Sparkle is pinned to 2.9.3 by hash; upstream is 2.9.4.
- 67 remote branches. Do not clean them up as a side task.
