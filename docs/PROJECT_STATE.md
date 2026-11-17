# Project State

Last updated: 2026-11-17

Short, current source of truth. Update this file at the end of every work cycle.
Everything historical lives in `docs/CURRENT_STATE.md` and `docs/DECISIONS.md`.

---

## Baseline

| | |
|---|---|
| Released version | `v1.2.1` / build `43` |
| `main` commit | `f24f506b3247bafcf00bd1d9610870a299bebdf8` |
| Branch tip in use | `fix/single-window-focus`, fast-forwarded on 2026-11-17 to the Background Tab Hover commit. That commit sits on `worktree-codebase-audit` (`3dac94d`), so the branch now carries the audit cleanup too. |
| Cleanup branch | `worktree-codebase-audit` (on top of `afc97b3`, `fix/single-window-focus` merged in at `d47e853`). Reached `fix/single-window-focus` on 2026-11-17 through the Background Tab Hover fast-forward, before its own click test; Gergő had run this build daily since 2026-11-11. See "Codebase audit cleanup" below. |
| Bundle ID | `com.gergoterek.HoverClick` |
| Project path | `/Users/terekgergo/Projects/HoverClick` |
| Signing identity | `HoverClick Dev` (self-signed) is in the login keychain: `security find-identity -v -p codesigning` lists it (measured 2026-10-25). The `Makefile` and the build scripts name it since `92c2678`. |
| Sparkle EdDSA private key | The old key is gone. A new key pair is in the login keychain since 2026-09-21 (`scripts/setup-signing.sh`; public key in `.signing/sparkle-public-key.txt`). `Info.plist:SUPublicEDKey` still holds the old public key, so `scripts/release.sh` stops until the release step replaces it. |
| Build status | Compiles with 0 warnings on macOS 27.0.1 / Apple clang 21. `scripts/build-app.sh` builds and signs with `HoverClick Dev`; the designated requirement is the same as the earlier build's, so the Accessibility grant carries over (measured 2026-10-25). Not notarized: a downloaded copy gets the Gatekeeper prompt. Since 2026-11-17 17:04 `pid 85798` runs the project root's `HoverClick.app`, built by `scripts/run-app.sh` from `92b2e18` (Background Tab Hover with the strip search, the overlay fix, the card drawn like Chrome's own and the site line read from the browser by Apple Event; the bundle's `Info.plist` carries `NSAppleEventsUsageDescription`; whether Gergő has answered macOS's permission prompt for Chrome is not known). Before it `pid 65027` ran `6c616a2` from 14:00 (Gergő saw the card of the 13:01 build, `43cf3e2`, at runtime and asked for the Chrome look); its log shows `Accessibility permission granted = YES`, `background tab hover started reason=launch` and `click listener installed`, and `scripts/tab-hover-harness.sh` passes 32 of 32 on that source. Earlier the same day: `pid 45254` from 00:11 (`63e90e0`, no card: the strip search was missing), `pid 26121` from 12:23 (`bb322ae`, no card under another application's overlay). Before that `pid 1861` ran the `worktree-codebase-audit` build from that worktree's `HoverClick.app`, started 3 minutes after the 2026-11-11 10:52 boot, so the Launch at Login item most likely points at the worktree copy (inferred, not checked). Turning Launch at Login off and on once from the root build should point it at the root copy (inferred). |

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

Since `92c2678` the `Makefile`, `scripts/build-app.sh`, `scripts/run-app.sh` and
`scripts/verify-app.sh` derive `PROJECT_DIR` through `scripts/release-config.sh`.
`scripts/package-dmg.sh`, `scripts/prepare-appcast.sh`, `scripts/checkpoint.sh` and
`scripts/performance-snapshot.sh` still hardcode the old machine's path; `scripts/release.sh`
does not use them.

---

## Work queue

Only one branch is worked on at a time. Finish or park the top item before starting the next.

| # | Branch | State |
|---|---|---|
| 1 | `fix/single-window-focus` | **18 commits on the branch, nothing uncommitted** (the menu bar utility clause is `eae5588`, see below; the build chain and the release pipeline are `92c2678` and `9353eb9`). `93ae113` and `c700de2` verified at runtime. `65c130f` (conditional activation plus a bounded wait) measured on 2026-09-14 and again on 2026-09-20 (22 Chrome attempts, 22 delayed YES). `fd5035d`, `ec56fc9`, `936d137` (2026-09-20 stability audit, see below) **not verified at runtime**. Not merged to `main`. |
| 1a | `worktree-codebase-audit` | In-place cleanup after the 2026-10-25 audit, on top of `afc97b3`, with `fix/single-window-focus` merged in (`d47e853`). Static checks PASS, **runtime test pending**. Reached `fix/single-window-focus` on 2026-11-17 with Background Tab Hover; the click test below now runs on the project root's build. |
| 1b | `worktree-bg-tab-hover` | Background Tab Hover, on top of `worktree-codebase-audit` (`3dac94d`), fast-forwarded into `fix/single-window-focus` on 2026-11-17. Two runtime tests on 2026-11-17 showed no card; both causes are fixed (the strip search, then other applications' overlays). Static checks PASS and `scripts/tab-hover-harness.sh` passes 32 of 32 with the card seen on screen; **Gergő's own hover test pending**. See "Background Tab Hover" below. |
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

## Background Tab Hover, 2026-11-17: two runtime tests failed, both causes fixed, harness passes

**Problem:** with another application frontmost, hovering a tab of a background Chrome window
shows nothing (no hover card, no expand-on-hover of the collapsed vertical strip). Chrome's
content view tracks the mouse only while Chrome is the active application. Cause, options and
limits: `docs/DECISIONS.md`, entry 2026-11-16.

**First runtime test, 2026-11-17:** Gergő saw no card. Cause, measured with read-only probes:
Chrome answers an Accessibility hit test over a vertical tab with an empty group the size of
the whole strip, so the read never reached a tab. Fix: the direct test searches the strip for
the tab under the pointer by frame; the card sits beside the strip. Details and probe results:
`docs/DECISIONS.md`, entry 2026-11-17. The runtime test below is still the one to run.

**Second runtime test, 2026-11-17:** still no card with Claude frontmost. Cause, measured:
other applications' click-through overlays (Floaty, Vorssaint, MonitorNotch) sit above the
normal level over the Chrome windows, and the window list step stopped at them before any
Accessibility read. Fix: overlays are passed over and the system-wide Accessibility hit test
decides what the pointer reaches. `scripts/tab-hover-harness.sh` now checks the whole chain on
live tabs: the tested build fails it, the fix passes 16 of 16 and the card was seen on screen.
Details: `docs/DECISIONS.md`, the newest 2026-11-17 entry.

**Change:** toggle `Background Tab Hover` (menu, first section, after Right Click Focus; on by
default). A 10 Hz pointer-position timer (only while a Chromium-family browser runs in the
background), Accessibility reads on a private queue, limited to the browser's tab strip zones,
and a click-through card that shows the hovered tab's title next to the tab. Nothing is
focused; keyboard focus stays in the frontmost application.

**Runtime test** (Gergő, on the build in the project root):

1. Claude (or any other application) frontmost on one monitor, typing in it; a Chrome window
   with vertical tabs on the other monitor.
2. Rest the pointer on a tab of that Chrome window for about 0.3 s, collapsed or expanded
   strip. Expected: a small card next to the tab with its full title. Typing continues in the
   frontmost application; Chrome does not come forward.
3. Move along the strip: the card follows from tab to tab. Move off the strip or click: the
   card disappears, and the click behaves as before.
4. Make Chrome frontmost: no HoverClick card (Chrome's own card works there).
5. Switch `Background Tab Hover` off in the menu: no card.
6. `Diagnostics > Copy Summary`: the `Background Tab Hover` lines show cards shown, hit tests,
   Accessibility timeouts and the slowest lookup.

---

## Codebase audit cleanup, 2026-10-25: static PASS, runtime test pending

Branch `worktree-codebase-audit`, on top of `afc97b3`, with `fix/single-window-focus` merged in
at `d47e853` (the HoverClick Dev build chain, the release pipeline and the menu bar utility
clause). What changed, why and what was
deferred: `docs/DECISIONS.md`, entry 2026-10-25. The architecture breakdown and the staged
modularization plan: `docs/ARCHITECTURE_AUDIT_2026-10-25.md`. In short: a stricter safety gate, the menu
refresh off the tap callback, a monotonic budget clock, a window search that stops at its first
timeout, honest verification for sibling-window clicks, the frontmost app's own panels passing
through again and about 200 lines of dead or duplicated code removed. `HoverClick.mm` is still
one file.

**Verified (static):** `clang++ -Wall -Wextra` 0 warnings (was 6), static analyzer 0,
`scripts/ci-safety-check.sh` and `scripts/source-only-check.sh` PASS in the worktree.

**Not verified:** anything at runtime. Before merging, run on a build of this branch:

1. The click test in the stability audit section below (steps 2 to 5). Its expected log lines
   already match this branch: `passed=` on the immediate verify line, `clickedWindowFront=` on
   the delayed line, `window search timed out stage=` for a blocked window search.
2. A panel of the frontmost application: TextEdit's Fonts panel or the Preview Inspector in
   front, click into the panel. Expected `ignored reason=already-frontmost` and no
   `click-to-focus started` line.
3. The menu in Light and Dark Mode: the submenu arrows are now dynamic colours and the row and
   header layout code was merged, so compare every row with a screenshot of the old build.
4. `Diagnostics > Copy Summary` after a Maccy or excluded-app click with Bypass Key set to Shift:
   `Last bypass decision` keeps the bypass value through the menu click.

---

## Multi-window focus bug: third fix under measurement

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

**Third fix:** `65c130f`. The second fix was necessary and not sufficient either. Measured on
2026-09-14 with the `c700de2` build and a 50 ms window-order watcher: activation carries the
application's key window, and the key window stays whatever Chrome had in front before the
click, whatever the AX operations say. The sibling rose above the covering window within
0.2 s in **6 of 8** clicks on a window that was not Chrome's topmost, and in **0 of 25**
clicks on Chrome's topmost window. `focusTargetApp:` now activates the application only when
the clicked window is already its topmost window (`isWindow:topmostWindowOfPid:outWindowID:outBounds:`),
and when it does, `waitForWindowIDToReachFront:reachedFront:` blocks the callback until the
clicked window is at the front of the CG window list, at most 150 ms, before the original
event is returned unchanged. The log line `activation decision ... wait=NNms reachedFront=YES/NO`
and the diagnostics summary carry the decision. Full reasoning and numbers:
`docs/DECISIONS.md`, entry "Activate only for the application's topmost window, then wait
for it to land".

**Runtime verification, 2026-09-06:** macOS 26.6.2, locally built bundle from `c700de2`, two
Chrome windows with a third application in front. On `click #37` the clicked window was
raised, the verbose readback reported `match=YES`, and the CGWindowList z-order right after
the click was clicked Chrome window, third application, sibling Chrome window, so the
sibling kept its place. The 2026-08-30 test of `93ae113` passed as well, but it did not
separate the clicked window from the application's main window, which is why it missed this
case.

**The 2026-09-06 sample that could not be attributed** (`click #34`, both Chrome windows
above the front application) is consistent with the 2026-09-14 finding: there the clicked
window was Chrome's main window, and main is not key. It stays unproven for that sample,
because the 2026-09-06 watcher had one-second resolution.

**Measurement since 2026-09-14 19:43** (`65c130f` build, export at 20:05:37, last click at
19:58:30; the 2026-09-20 sample is in the stability audit section below): 127 clicks, 8 click-to-focus attempts, 2 of them on a covered Chrome window with a
sibling below the cover (`#79`, `#111`). Both were clicks on Chrome's topmost window, the
sibling stayed in both, 0 rises within 0.2 s. Activation was requested 6 times, `wait=` 11 to
67 ms (median 12 ms, cap 150 ms never reached), `reachedFront=YES` 6 of 6, `delayed verify`
YES 6 of 6. **The changed branch has no Chrome sample yet:** since 19:43 nobody clicked a
Chrome window that was not Chrome's topmost, and that is the case the baseline failed in 6 of
8. The baseline collected its 8 such clicks in 11.5 hours; keep the build and the watcher
running until at least that many have accumulated, then re-run the scripts.

**Invariant 6, decided 2026-09-14:** `CLAUDE.md` invariant 6 ("no event replay or delayed
click delivery"), the same constraint in `docs/ARCHITECTURE.md`, and the recorded ban on the
35 ms activation-settle sleep of the failed background-drag experiment (`docs/TEST_MATRIX.md`,
`docs/CURRENT_STATE.md`) all touch the wait. The user decided that the bounded wait is
compatible: the invariant covers an event that is held back and delivered later, not a wait
inside the callback that returns the original event once, unchanged. The wait keeps its exit
condition and its 150 ms cap; raising the cap, dropping the exit condition or extending the
wait to skipped activations reopens the decision. Reasoning and limits: `docs/DECISIONS.md`,
2026-09-14 entry, paragraph "Invariant 6". The static gate cannot see the wait.

**Closed on 2026-09-20 (`fd5035d`, not yet run):** the immediate verification no longer reads
`NSWorkspace.frontmostApplication` inside the callback (it passed in **0 of 170** attempts
across the `c700de2` and `65c130f` builds; the value is refreshed on the main run loop, which
the callback blocks, inferred and not verified). It now combines the wait's window-list result
with the AX server's focused application (`kAXFocusedApplicationAttribute`), both on the
`immediate verify` log line as `windowList=` and `focusedAppAX=`, and the delayed verification
0.2 s later (the working signal so far: 156 of 162, 6 of 8 and 22 of 22 YES) runs after every
attempt. AX operation errors are counted (`failures=` in the operations summary) and a timed-out
operation abandons the attempt.

---

## Menu bar utility panels: fix built, runtime test pending

**Bug:** clicking a menu bar utility's non-activating panel (Emojist's emoji picker over Google
Chrome) made HoverClick activate the utility, so Chrome resigned and Google Docs dropped the
inline tab-rename field before Emojist could type into it. Adding Emojist to Excluded Apps
worked around it for one app.

**Fix (2026-09-17, committed as `eae5588` on 2026-10-25):** one clause in `nonNormalTopWindowSkipReasonForWindowInfo:`
plus `applicationLooksLikeMenuBarUtility:`. Owner of the topmost window is the target, the
window is at layer 24 or above, the target's activation policy is accessory: pass the click
through before any focus attempt (`Ignored Non-Normal UI`). Reasoning, numbers and rejected
options: `docs/DECISIONS.md`, entry 2026-09-17.

**State:** `scripts/source-only-check.sh` PASS. Ad hoc build in `HoverClick.app` from the
changed source (`scripts/build-app.sh` cannot run until `scripts/setup-signing.sh` has created
`HoverClick Dev`). The process running since 2026-09-17 19:04 (`pid 5918`) is that build: its
binary is dated 2026-09-17 13:22 and contains the clause's log text. **Not yet verified at
runtime:** the clause fired 0 times in the 2026-09-20 log, because Emojist is still in Excluded
Apps (5 clicks, all `excluded app`). Acceptance test: Emojist removed from Excluded Apps, Google
Docs tab rename open, emoji chosen with the mouse; expected log line `ignored
reason=non-normal-top-window ... target app is a menu bar utility ...` and the emoji lands in
the field. The change does not touch the Chrome path, so the sibling measurement above stays
comparable after the relaunch.

---

## Stability audit, 2026-09-20

Scheduled run, nobody at the keyboard. Full numbers and the reasoning in `docs/DECISIONS.md`,
entry 2026-09-20.

**Measured (unified log 08:06 to 13:56, 1,864 clicks):** 8 tap timeouts, each after one AX call
that blocked for 1.3 to 1.5 s (normal hit-test: 2 ms median, 17 ms p99). 64 focus attempts,
22 on Chrome (14 Google Docs, 3 Meet), all 22 `delayed verify frontApp=YES`, activation
requested in 21 (`wait=` median 37 ms, cap hit 3 times), skipped in 1. Same-point repeat clicks
within 2.5 s after a focus attempt: Chrome 1 of 22 (`#8828`/`#8829`, Docs, activation requested,
`wait=19ms`), Claude 1 of 8, Control Centre 3 of 7 (all activation skipped, `delayed NO`), others
0. No repeat sits next to a timeout marker; no Chrome click was stopped by an eligibility gate.

**Fixed (committed, static PASS, scratch build compiles, RUNTIME NOT TESTED):**

| Commit | Change |
|---|---|
| `fd5035d` | 200 ms AX messaging timeout on every element, 500 ms callback budget, focus attempt abandoned at the first timed-out write, activation wait cap shrinks with the budget (never above 150 ms), immediate verification from the window list and the AX focused application, delayed verification after every attempt, AX failures counted, verbose-only AX readbacks. |
| `ec56fc9` | `HoverClickLog` and `diagnosticLog:` carry the printf format attribute; the two `topmost CG window` lines passed an NSString to `%@` and logged a bare `@` (1,853 lines today). |
| `936d137` | No `imageWithSystemSymbolName:` call with a nil name (the last static-analyzer finding). |

**Not changed, decided against or deferred:** the activation policy of `65c130f` (no Chrome
evidence for the skipped-activation hypothesis: 1 skipped of 22, no repeat after it; `afc97b3`
later added `SetFrontProcessWithOptions(kSetFrontProcessFrontWindowOnly)` for a window that
becomes the process's front window after the raise); the already-frontmost gate still reads `NSWorkspace.frontmostApplication` (`HoverClick.mm`,
`handleResolvedElement:`), which can lag a fresh activation by one run-loop turn; window titles
still logged as `%{public}`.

**Click test for the next relaunch** (Gergő; the build is `scripts/build-app.sh` once
`HoverClick Dev` exists, or the scratch recipe in the audit chat):

1. Start: `log stream` is not needed; the unified log keeps the lines. Note the time.
2. Two Chrome windows side by side, both Google Docs, a third application (Finder) in front of
   the left one. Click once into the text of the covered left Docs window, on a word, and type
   one letter. Expected: the letter lands where the click was, without a second click. Log:
   `click-to-focus started target=Google Chrome`, `activation decision ... reachedFront=YES`,
   `immediate verify frontApp=YES windowList=reached focusedAppAX=Google Chrome`,
   `event passed through elapsed=NNms` under 200 ms, `delayed verify ... frontApp=YES`.
   Repeat 10 times; count the clicks that needed a second click.
3. Same arrangement, but click the Docs window that is **not** Chrome's topmost (the one
   behind the other Chrome window). Expected: only that window comes forward, the sibling stays.
   Log: `activation decision clickedWindowTopmostOfApp=YES mode=front-window-only
   skipReason=none ... reachedFront=YES`. A failure shows
   `skipReason=clicked-window-not-front-of-app-after-raise` (the raise did not settle within
   60 ms) or `skipReason=clicked-window-not-topmost-of-app` (no successful raise).
4. Sibling check with Chrome in front: the two Docs windows side by side with no other
   application over them, the right one key. Click once on a word in the text of the left
   window and type one letter. Expected: the letter lands where the click was, without a second
   click. Log: `behind a sibling window; focus attempt continues`, `immediate verify ...
   windowList=reached ... passed=YES`, `delayed verify ... frontApp=YES ...
   clickedWindowFront=YES`. Repeat 10 times; count the clicks that needed a second click.
5. Timeout check: open a Docs page with a long document, click Chrome's menu bar from another
   application ten times quickly. Expected: the click still lands and no `click listener paused
   by macOS` line appears. If an AX call blocks, one of these lines appears instead:
   `callback budget exhausted stage=`; `window search abandoned ... reason=ax-timeout`, then
   `window search timed out stage=`; `focus attempt abandoned reason=ax-timeout`. A window
   search cut off this way names its stage: `stage=window-resolution` or `stage=sibling-test`.
6. Export: `/usr/bin/log show --predicate 'processImagePath CONTAINS "HoverClick" AND
   eventMessage CONTAINS "[HoverClick]"' --start '<time from step 1>' --style compact` into a
   file; count the markers above.

---

## Measurement setup (temporary, machine-local)

**Gone since 2026-09-20.** The `zwatch` watcher is not running, and neither session scratchpad
named below exists any more. Only the unified log remains, and it keeps roughly half a day.
The watcher source was not copied into the repository; `tools/focus-observer.mm` (untracked,
2026-09-07) is a different probe that records activation notifications.

| | |
|---|---|
| Window-order watcher | `zwatch`, was pid `28175`, ran from 2026-09-12 20:21:45; **not running on 2026-09-20**. |
| Watcher log and scripts | were in `/private/tmp/claude-501/-Users-terekgergo-Projects-HoverClick/863c87a9-9d94-4612-981a-940c2e1bef7e/scratchpad/` (`zwatch.log`, `zwatch.swift`, `verdict.py`, `verdict2.py`, `hypo.py`, `analyze.py`); **directory gone**. |
| Wait statistics | were in `/private/tmp/claude-501/-Users-terekgergo-Projects-HoverClick/726b7681-7acc-4e50-93da-29f9155fc84c/scratchpad/`; **directory gone**. |
| Log export | `/usr/bin/log show --predicate 'processImagePath CONTAINS "HoverClick" AND eventMessage CONTAINS "[HoverClick]"' --start '<date time>' --style compact` (`/usr/bin/log`, because `log` is a zsh builtin) |
| Retention | The unified log keeps roughly half a day: on 2026-09-14 at 20:00 the oldest HoverClick line was from 08:56 the same day; on 2026-09-20 at 17:42 the oldest was from 08:06. Export before the data rolls out. |

---

## Development mode

Local build and runtime test are possible and were used to verify the focus fix.
Certificate-based signing is not, until a signing decision is made.

A local rebuild changes the bundle's code hash, so macOS drops its Accessibility permission.
After a rebuild, re-grant Accessibility in System Settings and then relaunch HoverClick: a
process that is already running keeps the denied state even after the toggle is set, and its
log keeps reporting `Accessibility permission granted = NO`.

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

- Background Tab Hover shows one title at a time. An emulated expanded strip (every title of a
  collapsed vertical strip at once) needs its own decision: a click-through list would send
  clicks to the page under it (`docs/DECISIONS.md`, 2026-11-16, "Rejected").
- Background Tab Hover covers Chromium-family browsers only. Safari's tab Accessibility shape
  is unchecked.
- `CLAUDE.md` invariant 6 does not say that a bounded in-callback wait is allowed; the reading
  lives in `docs/DECISIONS.md` (2026-09-14) and is restated in `docs/ARCHITECTURE.md`. Consider
  stating it in `CLAUDE.md` when that file is next edited.
- Accumulate clicks on a non-topmost Chrome window under `65c130f` (the baseline had 8 in
  11.5 hours) and re-run `verdict.py`, `verdict2.py` and `hypo.py`. Target: 0 sibling rises
  within 0.2 s.
- Verify `fd5035d` at runtime (AX messaging timeout, callback budget, the new immediate
  verification): the click test in the stability audit section above.
- Notification Centre: the new skip rule fires for its window, which is not a layer-0 window,
  so activation is skipped. The `c700de2` build activated it and it became frontmost in 2 of 3
  sampled attempts; with `65c130f` BusyCal stayed frontmost in 2 of 2. Decide whether that
  matters.
- The watcher source and the analysis scripts of 2026-09-14 are gone with their scratchpads
  (checked 2026-09-20). Rewrite `zwatch` into `tools/` before the next sibling measurement.
- The already-frontmost gate reads `NSWorkspace.frontmostApplication` inside the callback;
  compare it with the `focusedAppAX=` value on the `immediate verify` line once `fd5035d` runs,
  and switch the gate if the AX value is the live one.
- Replace the hardcoded `PROJECT_DIR` in the four remaining scripts (`package-dmg.sh`,
  `prepare-appcast.sh`, `checkpoint.sh`, `performance-snapshot.sh`) or retire them; the
  `Makefile` and the build, run and verify scripts are done (`92c2678`).
- Correct every document that still claims the old signing certificate is present.
- Decide the signing strategy for local development and for release.
- Decide what happens to the Sparkle update channel now that the private key is gone.
  Existing `v1.2.1` installations cannot be served an update signed by any new key.
- `HoverClick.mm` is a single ~4,900-line file. Extract `FocusController` once the focus
  behavior is settled.
- CI runs static safety checks only, no build.
- Static analyzer: 0 findings after `936d137` (it reported one nullability issue on
  2026-09-20, the nil SF Symbol name on the empty Excluded Apps row).
- Verbose diagnostics log AX element and window titles as `%{public}` (`HoverClick.mm:881`).
- Sparkle is pinned to 2.9.3 by hash; upstream is 2.9.4.
- 67 remote branches. Do not clean them up as a side task.
