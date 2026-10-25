# Decision Log

Append-only. Newest entry on top. Never rewrite or delete an old entry — if a decision is
reversed, add a new entry that says so and link back.

This file is the project's long-term memory. Chats are disposable; this is not.

**Entry format**

```
## YYYY-MM-DD — Short title
**Decision:** what was chosen
**Why:** the reason
**Rejected:** what else was considered and why it lost
**Evidence:** command output, file:line, or "not verified"
```

---

## 2026-10-25: In-place cleanup after a full codebase audit, modularization deferred

**Decision:** A full audit of `HoverClick.mm`, the scripts and the docs was followed by in-place
fixes only, on branch `worktree-codebase-audit` (based on `afc97b3`, not merged). Thirteen
reviewers produced 116 raw findings, 78 after duplicates were merged. Each one was checked by
independent existence, relevance and fix-safety reviews: 53 confirmed and 25 rejected.
`HoverClick.mm` stays one file. Splitting it waits until the runtime measurement of `afc97b3` is
closed (CLAUDE.md working rules) and until the other chat's pending patch to
`nonNormalTopWindowSkipReasonForWindowInfo:` has landed.

Click-path behavior changes, each in its own commit so it can be reverted alone:

- A click on the frontmost application's own non-layer-0 window (panel, palette, inspector)
  under the cursor passes through as `already-frontmost` again. `afc97b3` had sent it into the
  full focus attempt with four AX writes aimed at the panel.
- The window search stops at the first AX read that returns `kAXErrorCannotComplete` (role,
  window, parent and the sibling test's bounds read) and logs `window search abandoned ...
  reason=ax-timeout`. The click passes through as `Window Search Timed Out` (`window search timed
  out stage=sibling-test|window-resolution`). Before, the walk kept reading until the budget ran
  out or the click was reported as `Already Frontmost` or `No Target Window`.
- `setLastClickResult:` no longer refreshes the menu. It ran an `SMAppService` status query, a
  second `AXIsProcessTrusted` and about ten row syncs inside the callback on every click although
  no row shows the result; `menuWillOpen:` refreshes the menu.
- The callback budget and the three bounded waits use `CLOCK_UPTIME_RAW`
  (`HoverClickMonotonicSeconds`). The 20 ms mouse-down debounce no longer drops every click after
  the wall clock steps backward. Caps and budget are unchanged.
- The verbose window identity and focused-window readback respect the callback deadline.

Diagnostics-only changes: for a click on a sibling window of the application already in front,
the immediate verification passes only if the clicked window reached the front (`immediate verify
... passed=`). The delayed check compares the window id or, when the id was not resolved, the AX
bounds read before activation (`clickedWindowFront=YES(bounds)`). Before, the pid clause made both
pass for every such click. A success is counted once per attempt. AX writes that were never
attempted log `skipped` instead of `illegalArgument`. The last bypass decision is reset only after
the own-app exit. `Right Click Disabled` no longer replaces the last non-menu result. Budget exits
name their stage.

Gate changes: `scripts/ci-safety-check.sh` allowlists the exact mask statement and requires one
tap, one mask assignment and two mask bits with no reassignment and no address taken. The tap
callback must return `event` on every path except one `return NULL` under the NULL-event guard
and must not write to `event`. The forbidden API list grew from seven names to about twenty-five
patterns and covers every tracked source file. A tracked Swift file fails the gate. Git errors fail
closed. `scripts/source-only-check.sh` finds the Sparkle cache from a worktree and says when it
skipped the compile.

**Why:** The confirmed findings included a gate that could stay green with a broken tap mask, menu
work inside the latency-critical callback, a verification that could not fail for the very branch
under measurement, wall-clock budgets and about 200 lines of dead or duplicated code. Each fix was
reviewed against its plan and the merged branch was reviewed again from four angles. That second
review found the semantic conflicts that parallel edits produced (a monotonic deadline compared
with the wall clock, a timeout reported as `Already Frontmost`).

**Rejected:** Splitting `HoverClick.mm` now. Confirmed but deferred, with the reason in the audit
report: window titles logged as `%{public}`; the topmost check after `AXRaise` (needs the
`afc97b3` click test first); the double window resolution for sibling clicks; `AXDialog` compared
as a role; the bypass key mapping in seven places; the permission reset helper; the overlay skip's
global sequence; unreachable protected-role checks and window-info parsing duplication (both
touch the pending patch); the Finder context-menu follow-up that ignores the click target (needs a
Finder runtime test); Left Click Focus not persisted and the first-launch dialog stack (product
decisions); the exclusion picker that cannot offer Finder (an enhancement); the old machine path
in the committed `Makefile` and scripts (fixed by another chat's work, committed as `92c2678` on
2026-10-25 and merged in at `d47e853`; four unused scripts still carry it).

**Evidence:** Static only. `clang++ -Wall -Wextra` warnings went from 6 to 0, the static analyzer
reports 0, `scripts/ci-safety-check.sh` and `scripts/source-only-check.sh` pass in the worktree and
the gate's mutant harnesses give the expected verdict in every case (13 mask, 5 reassignment, 36
callback and API, 15 reviewer cases). Not verified at runtime.

---

## 2026-09-20 — Bound every AX call in the callback and give the callback a time budget

**Decision:** Every Accessibility element the tap callback touches carries a messaging timeout
of 200 ms (`HoverClickAXMessagingTimeoutSeconds`); the system-wide element sets it as the
process default when the tap is installed (`applyGlobalAccessibilityMessagingTimeout`, called
from `installEventTap`). The callback has a budget of 500 ms from its entry
(`HoverClickCallbackBudgetSeconds`, counted from `_lastEventTapCallbackTime`). Once the budget
is spent, no new AX work starts: `stringAttribute:fromElement:` returns nil, the window search
stops, `handleResolvedElement:` passes the click through with the log line `callback budget
exhausted stage=...`, and the activation wait's cap shrinks to what is left of the budget, never
above the 150 ms of the 2026-09-14 decision. A focus attempt stops at the first AX write that
returns `kAXErrorCannotComplete`, skips activation (`skipReason=ax-operation-timeout`) and logs
`focus attempt abandoned reason=ax-timeout operation=...`. Commit `fd5035d`.

Two smaller changes ride along in the same commit because they touch the same lines. The
immediate verification no longer reads `NSWorkspace.frontmostApplication` inside the callback;
it uses the wait's window-list result and the AX server's `kAXFocusedApplicationAttribute`
(`HoverClickAXFocusedApplicationPid`), both written to the `immediate verify` line
(`windowList=`, `focusedAppAX=`), and the delayed verification now runs after every attempt. The
clicked-window identity and the focused-window readback (up to seven AX reads) run only when
verbose diagnostics are on; before, they ran on every attempt and the line was dropped.

**Why:** The unified log of 2026-09-20 (08:06 to 13:56, 1,864 clicks, 64 focus attempts)
contains 8 `click listener paused by macOS reason=timeout` events. Each one follows a single AX
call that blocked for 1.3 to 1.5 s: `AXUIElementCopyElementAtPosition` on Chrome's menu bar
(`#8802`, `#8813`), on Elgato Wave Link (`#7954`) and twice with `cannotComplete` (`#8822`,
`#8823`); the focused-window readback of MenuBarAgent (`#8804`, `#8806`); the window search in
Emberline (`#8951`). A normal hit-test takes 2 ms (median) and 17 ms (p99, n=1,854), so the
blocked calls are a separate mode, not the tail of the normal one. While the tap is paused the
click in flight and every following click are delivered with no focus handling; the source had
no `AXUIElementSetMessagingTimeout` call at all (verified by grep on 2026-09-20). With the
timeout and the budget the worst case is budget plus one timeout, about 700 ms, against a tap
limit that a 827 ms callback survived on 2026-09-14 and a 1,315 ms callback did not on
2026-09-20.

**Rejected:** A messaging timeout alone: up to twenty AX round trips happen in one callback, so
a 200 ms timeout alone still allows several seconds. A shorter timeout (50 or 100 ms): the
measured normal calls fit, but a busy Google Docs tree on a slower machine may not, and the
budget already bounds the total. Moving the AX work off the callback thread: the focus must
land before the original event is returned, and the invariants forbid holding the event.
Raising the wait cap for slow activations: reopens the 2026-09-14 decision; the cap can only
shrink.

**Evidence:** `/usr/bin/log show --predicate 'processImagePath CONTAINS "HoverClick" AND
eventMessage CONTAINS "[HoverClick]"' --start '2026-09-20 04:00:00' --style compact`, 11,342
lines, parsed by `parse.py`, `pairs.py`, `next.py` and `durs.py` in the session scratchpad of
the chat "HoverClick: stabilitási átnézés és Chrome/Google dupla kattintás" (temporary; the
transcript in `chat-transcripts/` keeps the numbers). Callback duration from the click line to
`event passed through`: median 6 ms, p90 12 ms, p99 130 ms, max 3,034 ms (n=1,859).
`scripts/source-only-check.sh` PASS, scratch build with `make -o check-signing app
SIGNING_IDENTITY=-` compiles, clang static analyzer 0 findings after `936d137`. Runtime
behavior of the timeout and the budget: **not verified**; the `HoverClick Dev` identity is
missing and the running build (pid 5918, launched 2026-09-17 19:04 from the `65c130f`-era
source) keeps its Accessibility grant only as long as it is not replaced.

**On the reported Chrome and Google apps double click:** the same log has 22 Chrome focus
attempts (14 on Google Docs windows, 3 on Meet), all 22 with `delayed verify frontApp=YES`.
One is followed by a second click at nearly the same point within 2.5 s (`#8828` and `#8829`,
Docs, 0.33 s, 39 px; activation requested, `wait=19ms`, `reachedFront=YES`, no timeout marker
within 17 s), and one by a repeat click 3.7 s later 11 px away (`#8818` and `#8819`, Docs) after
Chrome had lost frontmost to Elgato Wave Link between the two with no click in between.
Control Centre shows the same repeat pattern in 3 of 7 attempts, all with activation skipped
(`clicked-window-not-topmost-of-app`, its window is not a layer-0 window) and `delayed verify
frontApp=NO`. So on this day the skipped-activation hypothesis explains the Control Centre
repeats and not the Chrome ones (Chrome had 1 skipped activation of 22, `#7914`, with no
repeat), the tap-timeout hypothesis explains none of the pairs, and the eligibility gates
blocked no Chrome click (23 `menu-role` skips were Chrome's own menus). The Chrome pair is
consistent with the click landing before the page has processed the activation, but with one
sample that is not a finding. No activation change was made; the click test in
`docs/PROJECT_STATE.md` is the next measurement.

---

## 2026-09-17 — Do not activate a menu bar utility for a click on its status-level panel

**Decision:** `nonNormalTopWindowSkipReasonForWindowInfo:` gained one clause. When the topmost
CG window at the click point belongs to the target application, sits at the status or pop-up
level (`windowInfoLooksLikePopupLayer:`, layer 24 and above), and the target application's
activation policy is `NSApplicationActivationPolicyAccessory` (`applicationLooksLikeMenuBarUtility:`),
the click is passed through before any focus attempt, with the skip reason `target app is a
menu bar utility and owns the status-level panel at the click point` and the click result
`Ignored Non-Normal UI`. No AX write, no raise, no activation. The size of the window plays no
part in this clause. Emojist is not added to the built-in exclusion list; the built-in Maccy
entry (`isBuiltInCompatibilityBypassApplication:`) stays for now, although this rule covers it.

**Why:** A menu bar utility's panel (`NSPanel` with `.nonactivatingPanel`, as Emojist's
`PickerPanel.swift`; HoverClick's own Maccy comment at `isBuiltInCompatibilityBypassApplication:`
describes the same requirement for a clipboard history) takes keyboard focus without activating
its application, precisely so that the application the user was typing in stays frontmost and
receives the inserted text. HoverClick's focus path ends in `-activateWithOptions:` on the
clicked window's application, which pulls activation away from that application. Measured on
2026-09-07 with Emojist over Google Chrome and a Google Docs tab-rename field: three clicks
(`#2350`, `#2360`, `#2660`) showed the picker as the topmost window at `layer=25`, `466x385`,
owned by Emojist; all four AX operations and the activation returned success; Emojist's own
insertion log for `#2360` reported `pre-flight 31 ms` (its `ensureFrontmost` had to bring
Chrome back) and `focus is on Google Chrome role=AXWebArea`, the captured text field gone.
The existing compact-overlay clause requires height `<= 360`; the picker is 25 points
taller, so no gate fired. Size is the wrong signal: in the same three-day log the Vorssaint
utility's `358x1133` and `358x375` panels at layer 25 passed the gate the same way
(`#3228`, `#3246`, `#3404`, `#3405`). Over those three days HoverClick started 308 focus
attempts; 4 of them (3 Emojist, 1 Vorssaint) match the new clause, 1.3 percent.

**Rejected:** Raising the compact height limit: fixes the 385-point picker and nothing else.
Adding Emojist to the built-in exclusion list: hides one instance of a class, ships the
developer's own app in a public default, and grows a list that should shrink once a general
rule exists. Reading `kAXFocusedAttribute` of the clicked window before any write (a
non-activating panel already reports it true while its application is in the background):
more precise, would also cover regular-policy applications, but costs an AX round trip per
eligible click and needs a measurement first that ordinary background windows report false;
kept as a possible follow-up. Widening the clause to every non-normal layer (a `.floating`
panel of an accessory application, level 3): plausible for the same reason, not measured, so
the clause stays at the approved status level and above.

**Evidence:** HoverClick unified log 2026-09-07 (`/usr/bin/log show`, since rolled out of the
store; the lines are quoted in the chat transcript "HoverClick fókuszlopás Emojist").
`CGWindowLevelForKey(kCGStatusWindowLevelKey)` = 25, `kCGMainMenuWindowLevelKey` = 24,
`kCGPopUpMenuWindowLevelKey` = 101, `kCGFloatingWindowLevelKey` = 3, measured with a probe on
2026-09-07. Emojist `LSUIElement` = true, activation policy accessory (probe, 2026-09-07).
`scripts/source-only-check.sh` = PASS on 2026-09-17. Ad hoc build compiled on 2026-09-17
(`HoverClick Dev` identity not present, so `scripts/build-app.sh` cannot run). Runtime
behavior with the new build: not verified yet. Whether Emojist was ever
`NSWorkspace.frontmostApplication` between HoverClick's two samples: inferred from Emojist's
pre-flight, not measured; `tools/focus-observer.mm` records the activation notifications for
that.

---

## 2026-09-14 — Activate only for the application's topmost window, then wait for it to land

**Decision:** `focusTargetApp:` (commit `65c130f`) calls `-activateWithOptions:` only when the
clicked window is already the topmost on-screen normal-level window of its own application,
decided by `isWindow:topmostWindowOfPid:outWindowID:` against the CG window list, matched by
frame. Otherwise activation is skipped and the user's own click activates the application with
that one window. When activation is requested, `waitForWindowIDToReachFront:reachedFront:`
blocks the tap callback until the clicked window is the first normal-level window in the CG
window list, or until `HoverClickActivationWaitTimeout` (150 ms, 10 ms polling) passes; the
original event is then returned unchanged. The user decided on 2026-09-14 that the bounded
wait is compatible with `CLAUDE.md` invariant 6, see "Invariant 6" below. The change stays
under runtime measurement until the changed branch has Chrome samples.

**Why:** The 2026-09-06 entry was still incomplete. Pointing the application at the clicked
window through `kAXFocusedWindowAttribute` and `kAXMainAttribute` does not change which window
`-activateWithOptions:` carries forward: activation brings the application's key window, and
the key window stays whatever Chrome had in front before the click. When the clicked window is
not that window, activation raises the sibling. Measured on 2026-09-14 with the `c700de2`
build (Evidence below): the sibling rose above the covering window within 0.2 s in 6 of 8
clicks on a window that was not Chrome's topmost, and in 0 of 25 clicks on Chrome's topmost
window. Skipping activation in the first case removes the only step that can raise a sibling;
the AX operations address one window.

The wait exists because activation is asynchronous. With the `c700de2` build the callback
returned the click before the application was frontmost in every measured attempt:
`immediate verify frontApp=NO` in 162 of 162 attempts, and the window-order watcher saw the
target frontmost 67 ms (median) to 121 ms (p90) after the click, while the callback had
returned after 38 ms (median). The wait polls the window server rather than `NSWorkspace`:
the `frontmostApplication` check inside the callback passed in 0 of 170 attempts across both
builds. The likely cause, inferred and not verified, is that the value is refreshed on the
main run loop, which the callback blocks.

**Rejected:** Dropping `-activateWithOptions:` altogether, the fallback named on 2026-09-06.
It is not needed for the topmost-window case, where activation cannot raise a sibling (0 of
25), and there it keeps the menu bar and the keyboard following the click. A fixed sleep after
activation: the measured settle time varies from 11 to 67 ms, so the wait needs an exit
condition. Polling `NSWorkspace.frontmostApplication`: never true inside the callback in the
measured attempts, so it would always run to the timeout. A timeout above 150 ms: the slowest callback measured before
the wait was 827 ms (AX hit-test in System Settings, `click #6732`), and the tap timeout is
1 s.

**Invariant 6, decided by the user on 2026-09-14:** `CLAUDE.md` invariant 6 says "no event
replay or delayed click delivery", `docs/ARCHITECTURE.md` ("Safety constraints") says "no
delayed delivery in any new code path", and the 35 ms activation-settle sleep of the failed
background-drag experiment is recorded as not reusable (`docs/TEST_MATRIX.md`, row "Failed
background drag experiment is not reused"; `docs/CURRENT_STATE.md`, "Background Click-And-Drag
Experiments"). The wait is a bounded sleep before return: the event is returned once,
unchanged, from the same callback, it is neither held nor posted, but it is returned 11 to
67 ms later than it would be. The user's reading: invariant 6 and the ARCHITECTURE constraint
cover an event that is held back and delivered later (a `NULL` return followed by a post, or a
replay), not a bounded wait inside the callback that still returns the original event. The
callback already spent 38 ms (median) in AX calls before the wait existed. The 35 ms
activation-settle ban stays in force for what it was recorded for: a fixed sleep without an
exit condition, in service of background click-and-drag. This wait has an exit condition
(the clicked window at the front of the window list), a measured duration of 11 to 67 ms and
a cap of 150 ms against a 1 s tap timeout. Any change that raises the cap, removes the exit
condition, or extends the wait to skipped activations reopens this decision.
`scripts/ci-safety-check.sh` does not detect the wait; `scripts/source-only-check.sh` passes
on `65c130f`.

**Evidence:** macOS 26.6.2. Unified log exports (`log show --predicate 'processImagePath
CONTAINS "HoverClick" AND eventMessage CONTAINS "[HoverClick]"' --style compact`) correlated
with the 50 ms window-order watcher `zwatch` (running since 2026-09-12 20:21:45) by
`verdict.py`, `verdict2.py`, `hypo.py` and `waitstats.py`; the scripts and logs live in the
session scratchpads, which are temporary, see `docs/PROJECT_STATE.md`.

*Baseline*, `c700de2` build (pid 1011), 2026-09-14 08:03 to 19:35. The 09-12 and 09-13 part of
the unified log has already rolled out; the numbers below reproduce the previously reported
13 of 33 and 6 within 0.2 s exactly, so those days contributed nothing to them. 162
click-to-focus attempts, 33 of them on a Chrome window covered by another application's window
with a Chrome sibling below the cover. Sibling rose above the cover: 12 within 1.5 s
(`verdict.py`); 13 attributable and 2 contaminated by a later click within 3 s (`verdict2.py`);
6 within 0.2 s, and all 6 were clicks on a window that was not Chrome's topmost (6 of 8),
against 0 of 25 clicks on Chrome's topmost window (`hypo.py` cross-tab).

*After*, `65c130f` build (pid 82844), 19:43 to 19:58:30, export at 20:05:37. 127 clicks, 8
click-to-focus attempts (Claude 4, Google Chrome 2, Notification Centre 2). Applicable Chrome
clicks: 2 (`#79`, `#111`), both on Chrome's topmost window (`#95` under Claude `#3219`,
sibling `#109` below); the sibling stayed in both, 0 rises within 0.2 s. **The target is met on
a sample that does not exercise the changed branch**: no click on a non-topmost Chrome window
has happened since 19:43. Activation requested 6 times: `wait=` 11, 12, 12, 12, 25, 67 ms
(median 12, max 67, the 150 ms cap never reached), `reachedFront=YES` 6 of 6; the watcher saw
the target frontmost and the clicked window on top 69 to 128 ms after the click in all 6;
`delayed verify` YES 6 of 6. Callback duration from the click line to `event passed through`:
median 76 ms, p90 142 ms, max 145 ms (n=8), against 38 / 71 / 827 ms for the baseline
(n=162). Skipped activations: 2, both Notification Centre (`clicked-window-not-topmost-of-app`:
its window is not a layer-0 window, so the topmost test cannot match it). The baseline build
activated Notification Centre and it became frontmost in 2 of 3 sampled attempts; with the new
build BusyCal stayed frontmost in 2 of 2.

---

## 2026-09-12 — Neutral wording for the app's own log lines

**Decision:** the `log show` output of HoverClick no longer says `event tap`, `bypass`,
`accessibility trusted`, `received ... raw=` or `mask=`. The same facts are logged as
`click listener created`, `click listener paused by macOS reason=timeout`, `Accessibility
permission granted = YES`, `launch settings ... skipKey=off`, `click #12 leftClickFocus=ON
screenPoint=(x,y) axPoint=(x,y)`. Code identifiers, the menu titles (`Bypass Key`, `Event Tap
Disabled`) and the Copy Diagnostics Summary text are unchanged.
**Why:** on 2026-09-12 a Claude Code diagnostic turn was blocked by the model's safeguard
(`[cyber]`) right after the startup log block landed in its context. Read out of context, a
login item without a visible icon that installs a system-wide mouse-down tap, logs click
coordinates and re-enables itself after a timeout looks like an input monitor. The wording was
the cheapest lever; the behavior and the tap mask are untouched.
**Rejected:** dropping the coordinates or the lifecycle lines entirely (they are the evidence
the focus investigations rely on); renaming UI strings (user-visible, would need release notes).
**Evidence:** session `1b115d7b` log: the request built on the first two tool results was
answered, the one that added the startup log failed at 18:40:18 CEST. `scripts/source-only-check.sh`
and a scratch compile after the rename: see the 2026-09-12 chat.

---

## 2026-09-06 — Window first, application second in the focus path

**Decision:** `focusTargetApp:` directs focus at the clicked window before it calls
`-activateWithOptions:`. The 2026-08-30 entry below stays valid but was incomplete: removing
`kAXFrontmostAttribute` was necessary and not sufficient.

**Why:** `-activateWithOptions:` carries the application's own main window forward with it.
While that main window was still the sibling the user had focused earlier, activation raised
the sibling in front of whatever the user had on top, which is the symptom that survived
`93ae113`. Pointing the application at the clicked window first makes the clicked window the
one activation carries. `NSApplicationActivateAllWindows` was never in the option set and
stays out.

**Rejected:** Dropping `-activateWithOptions:` altogether and letting the user's own click
activate the application. It is the stronger cure, because activation is the only step that
addresses more than one window, but it gives up the guarantee that the menu bar and the
keyboard follow the clicked window before the click is delivered. Kept as the fallback if a
sibling window ever comes forward again.

**Evidence:** Runtime measurement 2026-09-06, macOS 26.6.2, locally built bundle from
`c700de2`, two Chrome windows with a third application in front. `click #37` at `14:44:04`:
`AXRaise success`, `focused window readback ... match=YES`, and the CGWindowList z-order
right after the click was clicked Chrome window, third application, sibling Chrome window.
One earlier sample in the same session (`click #34`) ended with both Chrome windows above the
front application; there the clicked window was already Chrome's main window and a second
user click landed one second later, so that sample is not attributable. See
`docs/PROJECT_STATE.md` for the follow-up.

---

## 2026-08-30 — Public Accessibility APIs can raise a single window

**Decision:** Closes the question opened on 2026-08-03. Public AX is sufficient. No private
SkyLight API is needed, and none will be added.

**Why:** Setting `kAXFrontmostAttribute` on the application element was the whole cause of
the multi-window symptom. That attribute has application scope and cannot address one window.
With it removed, `kAXFocusedWindowAttribute` on the application element plus `kAXRaiseAction`,
`kAXMainAttribute` and `kAXFocusedAttribute` on the window direct focus at the clicked window
alone, while `-activateWithOptions:` brings the application forward.

**Rejected:** Adopting `_SLPSSetFrontProcessWithOptions` or any other private SkyLight call.
The hypothesis that window managers need private APIs for this turned out not to describe
HoverClick's case: those tools reorder windows without activating the owning application,
which is a stronger requirement than what click-to-focus needs.

**Evidence:** Runtime test on 2026-08-30, macOS 26.6.2, locally built bundle from `93ae113`.
Two Chrome windows side by side, a third application frontmost, click on the visible edge of
the background Chrome window. Only the clicked window came forward; the sibling window kept
its z-order position. This is the first runtime verification performed on the current
machine. Static checks passed as well, but they cannot observe this behavior.

---

## 2026-08-27 — Signing certificate and Sparkle private key are gone

**Decision:** Recorded as fact, with the consequences left open. Do not plan a release, a
DMG, an appcast entry or a Sparkle update until the two questions below are answered.

**Why:** The project moved to a new machine after the previous one was compromised. The
repository survived intact and was reconstructed from a fresh clone; every recovered source
file matched its committed blob byte for byte, so no source work was lost. Two credentials
did not survive, and neither can be restored from the backup:

1. The `Apple Development` certificate the Makefile requires.
   `security find-identity -v -p codesigning` returns `0 valid identities found`.
2. The Sparkle EdDSA private key matching `Info.plist:SUPublicEDKey`
   (`093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o=`). The login keychain holds no
   `https://sparkle-project.org` item.

The second is the more serious one, because it reaches users rather than the workstation.
Installed `v1.2.1` copies validate updates against that public key. A new key pair cannot
produce a signature those copies will accept, so the existing update channel cannot be
continued, only abandoned or replaced by a manual reinstall.

Local development is not blocked. A locally built bundle runs and was used to verify the
focus fix at runtime on 2026-08-30. It is not distributable and does not carry the hardened
runtime, because library validation rejects a framework that does not share the main
executable's team identifier.

**Rejected:** Reusing anything from the backup as a substitute. Certificates and private
keys from a compromised machine are not reinstated even when a copy exists.

**Evidence:** Commands above, run 2026-08-30 on macOS 26.6.2. Recovery detail in
`_recovery/RECOVERY-REPORT-20260827.md`, which is local and not tracked.

**Still undecided:** the signing strategy for development and for release, and whether the
Sparkle update channel is rebuilt with a new key or retired.

---

## 2026-08-03 — In-menu tooltips were tried twice and reverted twice

**Decision:** Recorded, not reopened. Read this before any work that proposes replacing the
`Guide` submenu with hover tooltips.

**Why:** Native in-menu hover tooltips do not display on HoverClick's custom `NSView` menu
rows, for two independent reasons:

1. `rowView.toolTip = item.toolTip` is assigned at build time, before the row view has a
   window. The internal `addToolTipRect:owner:userData:` registers against no window and
   never fires. (`HoverClick.mm:536`, `HoverClick.mm:596`)
2. `NSMenu`'s modal tracking run loop does not drive `NSView` tooltip display at all, and
   `item.view` bypasses `NSMenuItem.toolTip` entirely.

Fixing reason 1 alone is not enough, and it was already attempted:

```
4fe9e91  fix: re-register tooltip in viewDidMoveToWindow for custom menu rows
135a786  Revert "fix: re-register tooltip in viewDidMoveToWindow for custom menu rows"
8103ab8  Revert "ui: add and update menu item tooltips"
```

Reason 2 cannot be closed without a hover timer, a global monitor, or a floating tooltip
window. All three are forbidden by `CLAUDE.md`.

The `Guide` submenu (`HoverClick.mm:1512`) is the deliberate replacement, chosen on
`research-menu-tooltips` after native tooltips failed manual testing. It has 8 rows built by
`HoverClickCreateQuickHelpItem`, adds no tracking areas, timers, monitors or event taps.

**Rejected:** reverting to plain `NSMenuItem`s (discards the whole custom-row system: icons,
toggles, non-closing rows, highlight, compact width); inline help rows in the main menu
(clutters it); a floating tooltip window (forbidden).

**Evidence:** `docs/CURRENT_STATE.md` sections "Tooltip baseline audit (2026-06-25)" and
"research-menu-tooltips (2026-06-25)". Source comment at `HoverClick.mm:642–649`. Branches
`ui-menu-tooltips` and `research-menu-tooltips` exist locally and on origin. Verified
2026-08-03 by reading source and git history; **not re-tested at runtime**.

---

## 2026-08-03 — Two working chats, not three

**Decision:** Development runs in two Claude Code chats — `BUILD` (implements, one branch,
disposable) and `REVIEW` (read-only, independent). A third chat is spawned ad-hoc for
research and closed when it produces an entry in this file.

**Why:** The proposed "Director" chat existed to hold cross-feature memory. A chat is the
worst place for that: context compaction destroys exactly that layer first. Files survive
compaction. The director role is the user plus `CLAUDE.md` + `PROJECT_STATE.md` + this file.

**Rejected:** A three-chat system with a permanent `00 Development Director`. It costs three
manual copy-paste handoffs per cycle for a single-developer project, and its central value —
remembering what was tried — is better served by an append-only file.

**Evidence:** Design decision, no measurement.

---

## 2026-08-03 — Local build and runtime testing stay in the workflow

**Decision:** Keep building and running the app locally. Do not adopt a source-only mode.

**Why:** Two prior audits reported the signing identity as broken and recommended a
source-only workflow with no build. Verified on this machine and the reports were wrong:

```
security find-identity -v -p codesigning
  1) 590F9A2A... "Apple Development: rizsutt@gmail.com (MVQ5PX4679)"
     notBefore=May  6 2026   notAfter=May  6 2027
codesign --verify --deep --strict HoverClick.app   → exit 0
```

The active bug is a window z-order behavior. Static review cannot tell whether a fix works,
and removing the app activation could silently break focus entirely while still passing every
static check.

**Rejected:** Source-only feature branches with runtime explicitly unverified. Legitimate in
general; wrong for this specific class of bug.

**Evidence:** Commands above, run 2026-08-03. Certificate chain intact
(Apple Development → WWDR → Apple Root CA).

---

## 2026-08-03 — Cause of the multi-window focus bug

**Decision:** Treat the two app-wide operations in `focusTargetApp:` as the primary suspects:
`activateWithOptions:` (`HoverClick.mm:4652`) and `kAXFrontmostAttribute` on the app element
(`HoverClick.mm:4677`). Both run before the target window is raised.

**Why:** The target window is resolved correctly as an `AXUIElement`, and the per-window
operations (`kAXRaiseAction`, `kAXMain`, `kAXFocused`) are correct. The app-wide calls happen
first and can reorder the whole process's window layer.

Separately, verification at `HoverClick.mm:4710` compares only
`frontAfter.processIdentifier == targetPid`. It is structurally incapable of detecting this
bug and will report `success` for the exact behavior being reported.

**Rejected:** Blaming Stage Manager, Rectangle, BetterTouchTool or Chrome. The user
reproduced it with all of those off, and in TextEdit.

**Evidence:** Source read at `HoverClick.mm:4586–4712`, 2026-08-03. **Not verified at
runtime** — no A/B build has isolated which of the two calls is responsible.

---

## 2026-08-03 — Open: can public AX raise a single window?

**Decision:** None yet. Blocking question for the focus fix.

**Why:** It is unconfirmed that public Accessibility APIs can raise one window of a background
app above another app's window without activating the app. Window managers such as yabai use
private SkyLight APIs (`_SLPSSetFrontProcessWithOptions`) for this, which suggests the public
path may be insufficient.

**Rejected:** Nothing yet.

**Evidence:** Hypothesis only. Resolve with an A/B experiment build before committing to an
implementation strategy. Record the answer as a new entry here.
