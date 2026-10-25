# HoverClick architecture audit, 2026-10-25

Snapshot of commit `afc97b3` (5,500 lines in `HoverClick.mm`). Line numbers below refer to that
commit, not to the cleanup branch. Produced by a 13-reviewer audit; every finding was checked by
independent reviews before it was fixed or deferred. The cleanup itself, the deferred findings and
the reasons are recorded in `docs/DECISIONS.md`, entry 2026-10-25.

## Status of the architectural flaws after the cleanup branch

| Flaw (section 6 below) | State on `worktree-codebase-audit` |
|---|---|
| 1. God object | Unchanged. The split waits for the end of the `afc97b3` measurement (section 7). |
| 2. UI work inside the callback | Fixed: `setLastClickResult:` no longer calls `updateMenuTitles`. |
| 3. Diagnostics interleaved with decisions | Partly: the left and right handlers share one skip epilogue; the rest waits for stage 3. |
| 4. Stringly-typed state | Unchanged, except that the volatile result set is built once. |
| 5. Hidden coupling to the callback clock | Partly: the budget, the waits and the verbose AX reads use one monotonic clock; the budget is still read from an ivar. |
| 6. Duplicate work on the hot path | Partly: the verbose-off topmost log work is gone; the double window resolution for sibling clicks is deferred. |
| 7. Scaling with window count | Unchanged. |
| 8. Hard-coded policy data | Unchanged (the predicates sit next to another chat's pending patch). |
| 9. Configuration split across sources | Unchanged; persisting Left Click Focus is a product decision. |
| 10. Menu row view re-implements NSMenu | Layout code merged; behavior unchanged. |
| 11. Testability | Unchanged; stage 4 below. |
| 12. Tooling drift | Gate fixed and hardened; the old machine path in the committed `Makefile` and scripts is fixed only in another chat's uncommitted work. |


Some reviewer notes were wrong and the code wins:
- The file has **5,500 lines**, not 5,519.
- The delegate has **77 ivars**, not 64.
- There are **92** `HoverClickLog` call sites.

---

## 1. Components

### 1.1 Logical modules inside `HoverClick.mm`

| # | Module | Lines | Main symbols | On click path? |
|---|---|---|---|---|
| M1 | Constants | 1-101 | 4 bundle IDs (17-20); defaults keys `excludedAppBundleIDs` (21), `rightClickFocusEnabled` (24), `launchAtLoginOnboardingPromptShown` (25), `bypassKey` (49); about 20 help strings (26-45); bypass enum Off=0/Shift=2/Fn=3 (46-48); menu metrics (50-79); timing (80-101) | constants only |
| M2 | Info.plist / version helpers | 103-167 | `HoverClickDisplayVersion`, `BuildVersion`, `InfoString`, `InfoBoolStatus`, `HeaderVersion` (dead) | no |
| M3 | Diagnostic string helpers | 169-251 | `HoverClickDiagnosticTimestamp` (allocates an `NSDateFormatter` on every call), `EventTypeName`, `FocusTriggerLabel`, `RunningApplicationDescription`, `PointDescription`, `TruncatedDiagnosticString`, `StringContainsCaseInsensitive` | **yes** |
| M4 | Menu row view | 284-536 | `HoverClickMenuRowView`: `initWithMenuItem:…rowWidth:` (322), `setFrameSize:` (390), its own tracking-area highlight (416-438), `syncFromMenuItem` (450), modal `mouseDown:` loop (498, `nextEventMatchingMask` at 506) | no |
| M5 | Menu row and item factories | 538-893 | `HoverClickUse{Closing,NonClosing,Submenu,…}Row`, `HoverClickCalculatedSubmenuWidth` (576), `HoverClickSyncMenuRowView` (650), `HoverClickCreateQuickHelpItem` (669), section headers (726-850); dead: `HoverClickCreateHeaderMenuItem` (852), `HoverClickStatusDotImage` (713) | no |
| M6 | Logger | 895-920 | `HoverClickLog`: printf-checked; `vsnprintf` into 1 KB, then `printf`, `fflush` and `os_log(%{public}s)` | **yes** |
| M7 | AX C helpers | 922-1049 | `HoverClickAXErrorName`, `AXAttemptSummary`, `AXWindowIdentity` (954), `FocusedWindowComparison` (1002), `AXFocusedApplicationPid` (1032). None of them can see the callback budget | **yes** |
| M8 | Delegate interface | 1051-1120 | `HoverClickAppDelegate <NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate>`: 15 properties, 41 declared methods | |
| M9 | Ivars | 1122-1200 | 77 ivars (section 3) | |
| M10 | Tap callback | 1202-1242 | `HoverClickEventTapCallback` (a C function inside `@implementation`) | **yes** |
| M11 | App lifecycle | 1244-1347 | `applicationDidFinishLaunching:` (1244, 92 lines), `applicationDidBecomeActive:` (1337), `applicationWillTerminate:` (1344) | no |
| M12 | Status menu construction | 1349-1754 | `createStatusItem` (1349, 377 lines), `resetMenuRowHighlightsInMenu:` (1732), `menuWillOpen:` (1743) | no |
| M13 | Launch status and Launch at Login | 1755-1855 | `printLaunchStatus`, `logLaunchAtLoginStatus:force:`, `updateLaunchAtLoginMenuItem` (1812; queries `SMAppService` on every call) | indirectly, through `updateMenuTitles` |
| M14 | Permission and onboarding | 1856-2020 | `accessibilityTrusted` (1856), `removeEventTapDueToMissingAccessibilityWithReason:` (1865), `refreshAccessibilityStatusForReason:promptIfMissing:updateLastAction:` (1914), `requestAccessibilityTrustPrompt` (1948), `showAccessibilityOnboardingIfNeeded` (1956) | `accessibilityTrusted`: yes |
| M15 | Tap lifecycle | 2022-2063, 2355-2551 | `updateEventTapLifecycleFlags` (2030), `installEventTap` (2355), `removeEventTap` (2441), `handleEventTapDisabledWithReason:shouldReenable:` (2479), dead `toggleEventTap:` (2530) | the disabled handler runs inside the callback |
| M16 | Callback recording and decision history | 2065-2353 | `recordEventTapCallbackWithType:event:proxy:` (2065; starts the budget clock), `handleEventTapCallbackWithMissingAccessibilityForType:` (2091), `recordFocusDecisionWithTrigger` (2134), `recordBackgroundFocusAttempt/Result` (2157/2174), `recentDecisionEntryForSequenceID` (2186), `refreshLastRealBackgroundClickDecisionFromEntry` (2202), `updateRecentDecision…` (2229), `beginRecentDecision…` (2243), `includeRecentDecision…` (2286), `completeRecentDecision…` (2303), `recordMenuStatusDecision…` (2310), `recentDecisionHistoryDescription` (2317) | **yes** |
| M17 | Settings toggles and onboarding offer | 2552-2710 | `toggleClickToFocus:`, `toggleRightClickFocus:`, `toggleAutomaticUpdateChecks:`, `toggleLaunchAtLogin:` (2590), `offerLaunchAtLoginOnboardingIfNeeded` (2625, `runModal`), `toggleVerboseDiagnostics:`, `selectBypassKey:` (2696) | no |
| M18 | Diagnostics report | 2711-3084 | `clickDetectionStatusForDiagnostics` (2721, which **mutates** the lifecycle flags), `diagnosticDescriptionForClickResult:` (2747, 97 lines), `diagnosticsSummaryText` (2853, 209 lines, one positional format string), `copyDiagnosticsSummary:` (3063) | no |
| M19 | Static UI actions | 3085-3143 | About, three URL actions, Uninstall | no |
| M20 | Menu sync and last-result state | 3144-3242 | `updateMenuTitles` (3144), `setLastClickResult:` (3192), `shouldPreserveAsLastNonMenuClickResult:` (3200, builds an 18-literal `NSSet` on each call), `diagnosticLog:` (3229) | **yes** |
| M21 | Budget and AX timeout | 3244-3294 | `callbackElapsed` (3244), `callbackBudgetRemaining` (3248), `callbackBudgetExhaustedForSequenceID:…` (3254), `applyAccessibilityMessagingTimeoutToElement:` (3269), `applyGlobalAccessibilityMessagingTimeout` (3281) | **yes** |
| M22 | Exclusions and the app picker | 3295-3606 | `isChromeApplication:`, `userExcludedBundleIDs` (3299; reads `NSUserDefaults` on every call), `buildExcludedAppsSubmenu` (3311), `installedApplicationsForSelector` (3393), `displayNameForExcludedBundleID:` (3448), `chooseExcludedApp:` (3470), `addExcludedBundleID:` (3523), `removeExcludedApp:` (3564), `isBuiltInCompatibilityBypassApplication:` (3584), dead `isExcludedApplication:` (3597) | `userExcludedBundleIDs` and the Maccy check: yes |
| M23 | Click investigation notes | 3607-3677 | `browserContentDiagnosticNoteForTargetApp:…` (3607), `recordClickThroughInvestigationForSequenceID:…` (3653) | **yes** |
| M24 | Click entry handlers | 3678-3890 | `handleLeftMouseDown:` (3678), `handleRightMouseDown:` (3768), `accessibilityPointForEventPoint:` (3860, identity), `copyElementAtAccessibilityPoint:` (3864) | **yes** |
| M25 | Decision tree | 3887-4352 | `handleResolvedElement:…` (3887 wrapper; 3891, 381 lines), `passThroughForExhaustedBudget…` (4275), the Finder right-click follow-up state machine (4293-4352) | **yes** |
| M26 | Window-list geometry and waits | 4353-4612 | `topmostWindowInfoAtPoint:` (4353), `readBounds:ofAXWindow:` (4387), `areBounds:frontWindowOfPid:outWindowID:` (4417), `isWindow:topmostWindowOfPid:` (4450), `clickedWindowOfElement:isBehindSiblingOfPid:` (4461), `waitForWindow:toBecomeFrontWindowOfPid:` (4484), `activateFrontWindowOnlyOfPid:` (4513), `waitForFocusedElementOfApp:…` (4528), `waitForWindowIDToReachFront:` (4564), `logTopmostWindowInfo:` (4594) | **yes** |
| M27 | Non-normal window classification | 4612-4926 | `passThroughUnresolvedClick…` (4612), **`nonNormalTopWindowSkipReasonForWindowInfo:` (4642-4679, pending patch from another chat)**, `recordOverlaySkipWithReason` (4681), `recordNonNormalTopWindowDidNotBlock` (4704), pure predicates over the CG dictionary (4736-4908, with `windowInfoLooksLikeCompactOverlay:` at 4843 sitting next to the pending patch), `shouldIgnoreRole:` (4909), `shouldIgnoreWindowRole:` (4916) | **yes** |
| M28 | Focus engine and verification | 4927-5466 | `recordSuccessfulBackgroundFocus…` (4927), `completeDelayedBackgroundFocusVerification:` (4945, 81 lines, main queue +200 ms), `focusTargetApp:…` (5027, 360 lines), `copyWindowForElement:` (5388), `roleLooksLikeWindow:` (5440), `stringAttribute:fromElement:` (5446; returns nil once the budget is spent) | **yes** |
| M29 | Misc actions and `main` | 5468-5500 | `openAccessibilitySettings:`, `quitApplication:`, `main()` (5488) | no |

### 1.2 Tooling around the source

| Tool | Role | State at `afc97b3` (verified) |
|---|---|---|
| `Makefile` (78 lines) | `check-signing`, `prepare-sparkle` (Sparkle 2.9.3, SHA-256 pinned at 52-62), `clang++`, plist copy, `ditto` Sparkle, 6 `codesign` calls | Line 1 hardcodes `PROJECT_DIR := /Users/gergoterek/Movies/OBS/GPT/HoverClick` and that path does not exist. `SIGNING_IDENTITY` is still the old Apple Development cert |
| `scripts/build-app.sh` (19), `run-app.sh` (33), `verify-app.sh` (123), `package-dmg.sh` (265), `prepare-appcast.sh` (225), `checkpoint.sh` (153), `performance-snapshot.sh` (41) | build, launch, bundle check, DMG, appcast, build+commit+push | All hardcode the same dead path. The root checkout's pending patch (another chat) fixes `Makefile`, `build-app.sh`, `run-app.sh` and `verify-app.sh` through `release-config.sh`. It leaves `package-dmg.sh`, `checkpoint.sh`, `prepare-appcast.sh` and `performance-snapshot.sh` broken |
| `scripts/ci-safety-check.sh` (178) | the invariant gate | It greps 7 forbidden identifiers **in `HoverClick.mm` only** (52-75). It extracts the mask block with `sed -n '/CGEventMask mask =/,/CGEventTapCreate/p' HoverClick.mm` (81) and checks for `MouseMoved` and `ScrollWheel`. It also checks the bundle ID, `zsh -n` on the scripts, tracked artifacts and doc wording. The path is derived (`${0:A:h:h}`) |
| `scripts/source-only-check.sh` (126) | `git diff --check`, whitespace, the safety suite, `clang -fsyntax-only` | The compile step runs only if the Sparkle cache exists under `PROJECT_DIR/tmp`. Otherwise it is skipped silently |
| `.github/workflows/safety-checks.yml` | CI | It runs only `ci-safety-check.sh` on `macos-latest`. There is no build and no compile check |
| `Info.plist` (36) | bundle `com.gergoterek.HoverClick`, `SUFeedURL`, `SUPublicEDKey` | |

---

## 2. End-to-end data flow of one left click

### 2.1 Threading model

**Verified:**
- `installEventTap` calls `CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, …)` (2392-2396).
- The mask is exactly `CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)`.
- The source is added with `CFRunLoopAddSource(CFRunLoopGetCurrent(), …, kCFRunLoopCommonModes)` (2424) from the main thread.

The consequences:
- The callback runs on the **main thread** and holds every system-wide left or right mouse-down until it returns. That includes menu tracking, the `HoverClickMenuRowView` loop (506) and every `runModal` alert.
- No background queue, `NSThread`, `NSTimer` or lock exists in the file. Nothing spins the run loop inside the callback (the waits use `usleep` at 4498, 4553 and 4586). So the callback cannot re-enter and no ivar is ever shared across threads.

### 2.2 Step by step

| Step | Where | What happens | Reads from AX / CGWindowList / NSWorkspace | Pass-through exit (result string) |
|---|---|---|---|---|
| 0 | window server | A left mouse-down goes to the HID-level tap | | |
| 1 | `HoverClickEventTapCallback` 1202 | A nil refcon returns `event` (1207) | | |
| 2 | `recordEventTapCallbackWithType:` 2065 | **Starts the budget clock** (`_lastEventTapCallbackTime = now`, 2067, wall clock). Formats `_lastEventTapCallbackDescription` (a new `NSDateFormatter`) and bumps the per-type counters | | |
| 3 | 1213-1223 | `kCGEventTapDisabledByTimeout` / `ByUserInput` go to `handleEventTapDisabledWithReason:shouldReenable:YES` (2479). That method re-enables the tap or removes and reinstalls it, **inside the callback** | | returns `event` |
| 4 | 1224 | A NULL event returns NULL | | |
| 5 | 1228-1232 | `AXIsProcessTrusted()` runs on every mouse-down. If it is NO, `handleEventTapCallbackWithMissingAccessibilityForType:` (2091) writes `_lastClickResult` directly and schedules one deduplicated `dispatch_async` that removes or reinstalls the tap | AX trust | returns `event` |
| 6 | `handleLeftMouseDown:` 3679-3684 | **20 ms throttle** against `_lastMouseDownLogTime`: the click passes through with no record at all | | silent |
| 7 | 3685-3695 | Bypass key (Shift or Fn) via `CGEventGetFlags`; writes `_lastBypassDecision` | | silent (log line only) |
| 8 | 3696-3701 | `_clickSequence++`; `accessibilityPointForEventPoint:` (identity, 3860); `beginRecentDecisionWithTrigger:` (2243) builds a 27-key `NSMutableDictionary` with a second `NSDateFormatter` | `NSWorkspace.frontmostApplication` (2246) | |
| 9 | 3709 | `_clickToFocusEnabled` gate | | `Disabled` |
| 10 | 3729 | `passThroughRecentFinderRightClickFollowUpForClickID:` (4311): a left click within 5 s after a Finder right-click, while the same Finder pid is frontmost (rule from 98d9463) | `frontmostApplication` only when armed (4322) | `Finder Context Menu Pass Through` |
| 11 | 3733-3737 | `topmostWindowInfoAtPoint:` (4353) copies the full on-screen list. Then come `logTopmostWindowInfo:` and the history update with `compactWindowInfoDescription:`. That description runs twice even when verbose is off, because `diagnosticLog:` arguments are evaluated before its gate (4606/4608) | `CGWindowListCopyWindowInfo(OnScreenOnly)` #1, `NSRunningApplication` x2-3 | |
| 12 | `copyElementAtAccessibilityPoint:` 3864 | Creates a system-wide element, applies the 200 ms timeout and calls `AXUIElementCopyElementAtPosition`. It returns +1, which the caller releases at 3765 | AX hit-test | NULL: `passThroughUnresolvedClick…` (4612) returns `Ignored Non-Normal UI`, otherwise `No AX Element` |
| 13 | `handleResolvedElement:` 3891 | Reads role, subrole and title (3892-3894) via `stringAttribute:` (budget-aware) | AX x3 | |
| 14 | 3908 | budget check `element-attributes` | | `Budget Exhausted` (4290) |
| 15 | 3914 / 3933 | `AXUIElementGetPid`, then `NSRunningApplication runningApplicationWithProcessIdentifier:` | | `No Target PID` / `No Target App` |
| 16 | 3958 | built-in Maccy bypass | | `Excluded App (Maccy)` |
| 17 | 3977 | user exclusions via `userExcludedBundleIDs` (an `NSUserDefaults` read on every click) | | the user-excluded result (3992) |
| 18 | 4020 | own pid | | `Ignored Own App` |
| 19 | 4041 | Finder right-click arm (right-click only; a side effect) | | |
| 20 | 4045 | `shouldIgnoreRole:` 4909 (protected system UI role) | | `Ignored Menu/UI` |
| 21 | 4069-4074 | **`nonNormalTopWindowSkipReasonForWindowInfo:` (4642), the pending patch area** | owner lookups 4817/4872 | `Ignored Non-Normal UI` |
| 22 | 4111-4156 | Already-frontmost gate. `targetIsFrontmost` comes from `frontmostApplication`, which is stale inside the callback (DECISIONS 2026-09-14). The afc97b3 sibling test `clickedWindowOfElement:isBehindSiblingOfPid:` (4461) does a `copyWindowForElement` walk, `readBounds` (AX x2) and `areBounds` (CG list #2) | `frontmostApplication`, AX ≥4, CG #2 | `Already Frontmost` (4154). **About 96.6% of clicks exit here** (2026-09-20 log: 1,864 clicks, 64 attempts) |
| 23 | 4158 | `copyWindowForElement:` (5388): up to 10 ancestors; role, then `kAXWindowAttribute`, then `kAXParent`; budget checked per step | AX ≥2 | `No Target Window` |
| 24 | 4178-4195 | window role and title; `shouldIgnoreWindowRole:` (4916; reads `frontmostApplication` again) | AX x2 | `Ignored Transient UI` |
| 25 | 4221 | budget check `before-focus-attempt` | | `Budget Exhausted` |
| 26 | `focusTargetApp:` 5027 | `frontBefore` snapshot (5038), then `recordBackgroundFocusAttempt` sets `_lastBackgroundFocusSequence` | `frontmostApplication` | |
| 27 | 5050 | **second already-frontmost gate**: `isWindow:topmostWindowOfPid:` | AX x2, CG #3 | `Already Frontmost` (5068) |
| 28 | 5105-5158 | `AXUIElementCreateApplication`, then up to 4 AX writes at 200 ms each: `kAXFocusedWindow`, `AXRaise`, `kAXMain`, `kAXFocused`. `kAXErrorCannotComplete` sets `abandonedAfter` | AX writes x4 | |
| 29 | 5201-5203 | budget, then `isWindow:topmostWindowOfPid:` | AX x2, CG #4 | |
| 30 | 5213-5221 | If the window is not topmost after a successful raise: `waitForWindow:toBecomeFrontWindowOfPid:` (4484), **cap 60 ms**, 10 ms polls | CG per poll | |
| 31 | 5222-5232 | Activation. If the settle succeeded: `activateFrontWindowOnlyOfPid:` (4513; `GetProcessForPID` + `SetFrontProcessWithOptions(kSetFrontProcessFrontWindowOnly)`). If the window was already topmost: `activateWithOptions:NSApplicationActivateIgnoringOtherApps`. Then `waitForWindowIDToReachFront:` (4564), **cap min(150 ms, budget)** | CG per poll | activation skip reasons 5234-5238: `no-running-application`, `ax-operation-timeout`, `callback-budget-exhausted`, `clicked-window-not-front-of-app-after-raise`, `clicked-window-not-topmost-of…` |
| 32 | 5281 | `waitForFocusedElementOfApp:toBeInWindow:` (4528), cap `150 ms - activationWait` | AX x2 per poll | |
| 33 | 5268 | verbose only: `HoverClickFocusedWindowComparison` | AX ≤4 | |
| 34 | 5301 | immediate verification: `HoverClickAXFocusedApplicationPid` (system-wide AX) plus the window-list result | AX x1 | |
| 35 | 5326 / 5353 | `setLastClickResult:` `Succeeded` or `Verify Pending`, which calls `updateMenuTitles` **right before the event is delivered**. Then success and history bookkeeping; `completeRecentDecision…keepActive:YES` (5345/5365) | `SMAppService` status, `AXIsProcessTrusted` | |
| 36 | 1241 | the callback returns the **original `event` unchanged** | | |
| 37 | 5381 → 4945 | `dispatch_after(0.20 s, main)`: `completeDelayedBackgroundFocusVerification:`. Stale guard against `_lastBackgroundFocusSequence`; compares `frontmostApplication` with the target pid; overwrites `_lastClickResult` only if it is still `Verify Pending`; removes the active history entry | `frontmostApplication` | |

**Every skip exit** runs the same five calls:
1. `recordFocusDecision…`
2. `recordClickThroughInvestigation…`
3. `includeRecentDecisionInHistory…` (or `recordMenuStatusDecision…`)
4. `completeRecentDecision…keepActive:NO`
5. `setLastClickResult:` (which ends in `updateMenuTitles`)

Right-click (3768) runs the same pipeline with trigger `right-click`. It is gated by `_rightClickFocusEnabled`, which defaults to OFF because no default is registered. It skips step 10 and calls the full `handleResolvedElement:…trigger:` directly (3856).

### 2.3 Timing budget (recorded decisions, not defects)

| Item | Value | Constant |
|---|---|---|
| Per-AX-call messaging timeout | 200 ms | `HoverClickAXMessagingTimeoutSeconds` (94); global default set in `installEventTap` (2390), per element at 3870, 4469, 4540, 5106 and 5107 |
| Callback budget, from step 2 | 500 ms | `HoverClickCallbackBudgetSeconds` (100); checked between steps and by `stringAttribute:` and `copyWindowForElement:` |
| Raise settle | ≤60 ms, 10 ms polls | 88, 85 |
| Activation-to-front plus focused element | ≤150 ms shared | 84 |
| Delayed verification | +200 ms after return | 80 |
| Worst case inside the callback | about budget + one in-flight AX call ≈ 700 ms *(derived from the comment at 95-99)* | the tap timeout is about 1 s (comment 81-84) |

The pass-through branch A has no waits. Its cost is IPC plus bookkeeping: 2 window-list copies, ≥8 AX round trips, 2 `frontmostApplication` reads, 2 `AXIsProcessTrusted` calls, one `SMAppService` query and about 10 menu row syncs. A full focus attempt costs ≥17 AX round trips plus polls and up to about 25 window-list copies (perf-hotpath sweep, verified by reading).

---

## 3. State model

### 3.1 Ivars (1122-1200, 77 in total; verified by type count)

| Type | Count |
|---|---|
| `NSString` | 31 |
| `uint64_t` | 13 |
| `CFAbsoluteTime` | 13 |
| `BOOL` | 13 |
| `pid_t` | 2 |
| `NSInteger` | 1 |
| containers | 2 |
| CF tap refs | 2 |

Of these, 47 are `_last*` and 10 are `_total*`.

| Concern | Ivars | Written by | Read by |
|---|---|---|---|
| Tap lifecycle | `_eventTap`, `_eventTapSource`, `_userWantsEventTap` (always YES; `toggleEventTap:` 2530 is unreachable), `_eventTapInstalled`, `_eventTapEnabled`, `_eventTapRemovalScheduledDueToMissingPermission`, `_eventTapRemovedDueToMissingPermission`, `_permissionMissingPassThroughActive` | M14, M15, callback | menu, diagnostics |
| Feature flags | `_clickToFocusEnabled` (forced YES at 1250), `_rightClickFocusEnabled` (defaults), `_verboseDiagnostics` (forced YES at 1256), `_bypassKey` (defaults, sanitized 1253-1255) | launch, toggles | click path |
| Click sequencing and timing | `_clickSequence`, `_lastEventTapCallbackTime` (**both the diagnostics timestamp and the budget origin**), `_lastMouseDownLogTime` and `_lastRightMouseDownLogTime` (throttle), `_lastFinderRightClickPid/Time`, `_lastRightClickFocusPid/Time`, `_lastBackgroundFocusSequence` (staleness key for the delayed verification) | click path | click path, delayed verifier |
| Click outcome | `_lastClickResult`, `_lastNonMenuClickResult` (free-string vocabulary; about 28 literals, listed in 2.2) | `setLastClickResult:`, plus a direct write at 2098 | `diagnosticDescriptionForClickResult:`, the delayed verifier (5022) |
| Diagnostic snapshots | about 31 `_last*Description` strings (`_lastBackgroundFocus*`, `_lastOverlay*`, `_lastRealBackgroundClickDecisionDescription` rebuilt by every `updateRecentDecision…`, `_lastClickThroughInvestigationDescription`, …) and 10 `_total*` counters | click path | only `diagnosticsSummaryText` (2853) |
| Decision history | `_activeDecisionHistory` (`NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*,NSString*>*>`, 1199), `_recentDecisionHistory` (ring of 10, 2296) | M16 | Copy Diagnostics |
| Write-only (dead) | `_lastSuccessfulFocusTime`, `_lastSuccessfulFocusDescription`, `_launchAtLoginOnboardingOfferedThisLaunch` | | nobody |
| UI | 13 `NSMenuItem` properties, `statusItem`, `updaterController` (Sparkle), `accessibilityOnboardingAlert`, `_showRefreshStatusFeedback` | M12, M14 | `updateMenuTitles` |

### 3.2 User defaults

There are 4 own keys:
- `excludedAppBundleIDs`: no cache; it is re-read on every click.
- `rightClickFocusEnabled`
- `bypassKey`: the old value 1 (Option) maps to Off.
- `launchAtLoginOnboardingPromptShown`

The code calls `synchronize` 6 times (2564, 2577, 2665, 2704, 3548, 3575). Sparkle owns its own keys. Left Click Focus and Verbose are deliberately not persisted.

### 3.3 Timers and deferred work

There is no `NSTimer`. Deferred work uses these blocks:
- `dispatch_after` 2 s: "Refreshed" feedback (2013) and the "Copied" title (3077).
- `dispatch_async` main: tap removal for missing permission (2117) and the app picker (3475).
- `dispatch_after` 200 ms: delayed verification (5381).

All of them capture only `self` (plus one `NSDictionary` context at 5381).

### 3.4 Callback versus main run loop

Both run on the same thread so nothing is shared concurrently. The coupling is temporal:
- the callback drives `updateMenuTitles`, which means AppKit menu work inside the callback;
- the delayed verifier reads `_lastBackgroundFocusSequence` and the history entry the callback left active;
- menu and modal UI runs strictly between callbacks.

---

## 4. Lifecycle

1. **`main()`** (5488) creates `NSApplication` and keeps a strong local delegate for the process lifetime, which is why the unretained refcon at 2401 is safe. Then `-run`.
2. **`applicationDidFinishLaunching:`** (1244):
   - assigns about 75 ivars by hand (1247-1324);
   - reads the two defaults keys;
   - sets `NSApplicationActivationPolicyAccessory` (1326);
   - creates `SPUStandardUpdaterController` with `startingUpdater:YES` (1327).
   Then it calls, in order:
   - `createStatusItem` (1349; ends with `updateMenuTitles`);
   - `printLaunchStatus` (1755);
   - `refreshAccessibilityStatus:nil` (2004 → 1914), which installs the tap when trusted and otherwise takes the fail-open removal path at 1865;
   - `showAccessibilityOnboardingIfNeeded` (1956: the system prompt via `AXIsProcessTrustedWithOptions`, plus a non-modal `NSAlert` laid out before showing, per 5e53ac3);
   - `offerLaunchAtLoginOnboardingIfNeeded` (2625: a **modal** `runModal` on first run; the tap is already live and fires inside it).
3. **Permission changes**:
   - `applicationDidBecomeActive:` (1337), `menuWillOpen:` (1743) and the Refresh menu items call `refreshAccessibilityStatusForReason:…promptIfMissing:NO`.
   - Granted: clear the flags, dismiss the alert, `installEventTap` (idempotent).
   - Missing: `removeEventTapDueToMissingAccessibilityWithReason:`.
   - Revoked mid-session: caught per click at 1230 and removed asynchronously (2117).
4. **Tap install** (2355): permission gate; reuse, re-enable or recreate an existing tap; global AX timeout; create; source; add to the run loop; enable. CF ownership is correct on every failure path (verified). If enabling fails (2430), the tap stays installed and heals on the next install.
5. **Tap disabled by macOS** (timeout or user input): handled synchronously inside the callback (2479). It re-enables or does `removeEventTap` + `installEventTap` (2517-2518). *(Inferred safe: CFRunLoop retains the performing source during the callout.)*
6. **Menu updates**: `updateMenuTitles` (3144) is the single sync point. It reads `AXIsProcessTrusted`, `SMAppService.mainAppService.status` (via 1812) and Sparkle's `automaticallyChecksForUpdates` and re-syncs about 10 row views. It is called from `setLastClickResult:` (every click exit) and again by every toggle so each toggle syncs twice.
7. **Termination**: `quitApplication:` → `[NSApp terminate:]` → `applicationWillTerminate:` (1344) → `removeEventTap` (2441: disable, remove the source, release the source, release the port; no `CFMachPortInvalidate`, which is inferred harmless).

---

## 5. Measured structure (verified by script)

| Metric | Value |
|---|---|
| File | 5,500 lines |
| Classes | 2: `HoverClickMenuRowView` (284-536, 12 methods) and `HoverClickAppDelegate` (impl 1122-5486, **4,365 lines, 79% of the file**) |
| Delegate methods | 130 implemented, 41 declared in the interface, 15 properties |
| Ivars | 77 (47 `_last*`, 10 `_total*`) |
| File-scope `static` functions | about 45 |
| Largest methods | `handleResolvedElement:…trigger:` **381** (3891); `createStatusItem` **377** (1349); `focusTargetApp:…` **360** (5027); `diagnosticsSummaryText` 209 (2853); `diagnosticDescriptionForClickResult:` 97; `applicationDidFinishLaunching:` 92; `handleRightMouseDown:` 91; `handleLeftMouseDown:` 89; `installEventTap` 85; `completeDelayedBackgroundFocusVerification:` 81. The top three add up to 1,118 lines |
| Logging | `HoverClickLog` 92 call sites, `diagnosticLog:` about 20, raw `NSLog` 2 (107, 1786) |
| Bookkeeping call counts (duplication sweep) | `updateRecentDecision…` 37, `recordClickThroughInvestigation…` 27, `recordFocusDecision…` 26, `completeRecentDecision…` 22, `includeRecentDecision…` 18; `setLastClickResult:` 33 occurrences, 28 with a literal |
| Dead code | 6 compiler-reported unused symbols (66, 74, 165, 280, 639, 852), plus `HoverClickStatusDotImage`, `toggleEventTap:`, `isExcludedApplication:` and the 3 write-only ivars |

---

## 6. Architectural flaws

1. **God object.** `HoverClickAppDelegate` carries 16 responsibilities: lifecycle, menu, permission, tap, policy, geometry, AX focus engine, verification, history, snapshots, report, exclusions, Launch at Login, Sparkle, bypass key and About/Help. Evidence: 130 methods and 77 ivars in one `@implementation`. The click path cannot be instantiated without AppKit, Sparkle and `SMAppService`.
2. **UI work inside the latency-critical callback.** Every click exit calls `setLastClickResult:` → `updateMenuTitles` (3192 → 3144). That runs an `SMAppService` XPC status query, `AXIsProcessTrusted` and about 10 row-view syncs. On a focus attempt it happens after the waits (5326/5353), directly before delivery. No visible row shows `_lastClickResult` (verified at 3144-3190) so this work buys nothing on the click path. *(Its cost is inferred, not measured.)*
3. **Diagnostics interleaved with decisions.** About 60% of `handleResolvedElement:`'s statements build diagnostic strings:
   - `axTarget` is written 3 times (3895, 3998, 4240);
   - the browser note twice (4006, 4184);
   - the five-call skip epilogue is copied about 16 times;
   - `refreshLastRealBackgroundClickDecisionFromEntry` (a 16-field format) is rebuilt 14 times per focus attempt inside the callback;
   - `diagnosticLog:` arguments are evaluated before the verbose gate (4606/4608).
4. **Stringly-typed state.**
   - The click result vocabulary is about 28 free literals, compared with `isEqualToString:` in 3 places (2747-2843, 3205-3224, 5022). One writer bypasses the setter (2098).
   - The history entries are `NSString→NSString` dictionaries with 27 literal keys (2243).
   - The report is an 81-specifier positional `stringWithFormat:` (2853) so a misplaced argument is a silent bug.
5. **Hidden temporal coupling to the callback clock.**
   - `_lastEventTapCallbackTime` is both a diagnostic and the budget origin (2067, 3244).
   - `stringAttribute:` (5446) and `copyWindowForElement:` (5388) silently return nil or NULL once the budget is spent. Any future caller outside the callback gets wrong answers.
   - The C AX helpers (954-1049) cannot see the budget at all.
   - The budget uses the wall clock (`CFAbsoluteTimeGetCurrent`).
   - The perf sweep reports that the budget is checked between steps but not before each AX write at 5105-5158.
6. **Duplicate work on the hot path** (verified call sites):
   - the already-frontmost gate exists twice (4111-4156 and 5050-5068);
   - window walks run twice for a sibling click (4120 → 4465 and 4158);
   - `frontmostApplication` is read up to 4 times per click (2246, 4111, 4917, 5038) and all reads return the same stale value inside the callback;
   - window-info alpha and bounds parsing is hand-written 3 times (4357-4371, 4424-4434, 4575-4578) next to `boundsForWindowInfo` (4746);
   - the owner-pid → `NSRunningApplication` lookup appears 3 times (4769, 4817, 4872);
   - `AXUIElementCopyAttributeValue` appears at 12 sites in 6 hand-rolled patterns.
7. **Scaling with window count.** Every `CGWindowListCopyWindowInfo` copy is O(number of on-screen windows) and allocates a dictionary per window. One focus attempt can make about 25 copies, all inside the callback.
8. **Hard-coded policy data.** Bundle IDs, owner names and geometry thresholds for system UI and overlays are inline in the predicates (4790-4908). The Maccy and Chrome special cases are scattered (3053, 3296, 3331, 3531, 3587, 3958) and `isExcludedApplication:` (3597), the one combined check, is unused.
9. **Configuration split across sources.** Settings live in defaults (4 keys), in Sparkle and in non-persisted ivars forced at launch (1250, 1256). `ARCHITECTURE.md:77` describes a persisted default that does not exist.
10. **Menu row view re-implements NSMenu behaviour.** It has its own hover highlight (needs the reset at 1732) and its own modal `mouseDown:` loop (498-535), which calls the action before `cancelTracking`. So modal alerts open while the menu is still tracking and the frame math is duplicated between 322-384 and 390-403.
11. **Testability.** The click path has no seam. The policy predicates (4736-4908) are pure functions of a CG dictionary but they are instance methods on the delegate. Nothing can be unit-tested without a running app, Accessibility trust and real windows and CI compiles nothing.
12. **Tooling drift.** All build and release scripts except the two check scripts hardcode a non-existent path (Makefile:1). The compile gate is skipped silently and the safety gate knows exactly one file name (`ci-safety-check.sh:63, 81`).

---

## 7. Target architecture and staged modularization plan

**Precondition:** the runtime measurement on this branch is closed and its result is recorded in `docs/DECISIONS.md`. No stage changes behaviour. Each stage is one commit, re-runs the safety gate and is verified with a 1-day log comparison: the same click result distribution and the same callback duration percentiles from the existing `[HoverClick]` lines.

### 7.1 Target units (still one target, one binary)

| Unit | Contents (current lines) | Dependencies |
|---|---|---|
| `HCConstants.h` | timing, keys, bundle IDs (1-101) | none |
| `HCLog.{h,mm}` | `HoverClickLog`, the diagnostic string helpers, a cached date formatter (169-251, 895-920) | os_log |
| `HCAX.{h,mm}` | budget-aware AX reads and writes taking an explicit `HCClickBudget` (deadline from `mach_absolute_time`), `copyWindowForElement`, `readBounds`, the helpers 922-1049, 5388-5466 | ApplicationServices |
| `HCWindowList.{h,mm}` | one `HCWindowSnapshot` per call (parsed alpha, bounds, layer, pid once), topmost-at-point, front-window-of-pid, the waits (4353-4592) | CoreGraphics |
| `HCPolicy.{h,mm}` | pure classification over snapshot + role strings: protected roles, non-normal top window, compact overlay, pointer surface, transient window, exclusion set (4612-4926 minus recording). It returns an `HCSkipReason` enum with a string table | HCWindowList types only |
| `HCFocusEngine.{h,mm}` | raise, settle, activation, focused-element wait, immediate verification (5027-5386 minus bookkeeping). Input: an `HCClickContext` struct (pid, app, element, window, snapshot, front pid read once, budget). Output: an `HCFocusOutcome` struct | HCAX, HCWindowList |
| `HCClickPipeline.{h,mm}` | handlers + decision tree as an ordered gate list over `HCClickContext`. Exactly one exit function records the outcome | Policy, FocusEngine, Recorder |
| `HCDiagnosticsRecorder.{h,mm}` | counters, snapshots, decision history (typed struct per click), summary text, delayed verification bookkeeping (2065-2353, 2711-3084, 3607-3677, 4927-5025) | HCLog |
| `HCEventTap.{h,mm}` | **the only file allowed to contain `CGEventTapCreate`, the mask and the C callback**; install, remove, re-enable (1202-1242, 2022-2063, 2355-2551) | HCClickPipeline (protocol) |
| `HCMenu*.{h,mm}` | row view, factories, `createStatusItem`, `updateMenuTitles`, exclusions UI, toggles, About/Help (284-893, 1349-1754, 2552-2710, 3085-3190, 3295-3606) | Recorder (read only) |
| `HCAppDelegate.mm` | lifecycle, permission/onboarding, wiring (1244-1347, 1755-2020, 5468-5500) | all |

### 7.2 Stages

| Stage | Change | What it proves | Gate |
|---|---|---|---|
| 0 | **Make the gate split-proof before any split.** `ci-safety-check.sh`: forbidden-API grep over `git ls-files '*.mm' '*.m' '*.h' '*.c'` instead of `HoverClick.mm`; require exactly one `CGEventTapCreate` in the whole tree and that it sits in the allowed file; extract the mask block from that file; add the forbidden names from the non-source sweep (`CGEventTapPostEvent`, `CGEventCreateKeyboardEvent`, `CGEventCreateScrollWheelEvent`, `CGEventCreateCopy`, `CGEventSet`, `IOHIDPostEvent`, `postEvent:`, `addGlobalMonitorForEventsMatchingMask`, `kCGEventMaskForAllEvents`, `kCGEventLeftMouseUp`, `kCGEventLeftMouseDragged`, `kCGEventOtherMouseDown`); check that the callback returns only `event` or NULL. Fix `PROJECT_DIR` in the 4 remaining scripts. Add `clang -fsyntax-only` to CI with the Sparkle headers fetched (pinned SHA) | the current file passes every new rule (verified by the non-source sweep) | CI green on unchanged source |
| 1 | Extract the leaf units with no ivar access: `HCConstants.h`, `HCLog`, the menu factories and `HoverClickMenuRowView`. Delete the verified dead code in the same stage | a mechanical move compiles and the safety gate sees multiple files | build, `verify-app.sh`, menu looks identical |
| 2 | Introduce `HCClickContext` and `HCClickBudget` **inside `HoverClick.mm`**: the budget is passed explicitly instead of read from `_lastEventTapCallbackTime`; the front pid, owner app and window snapshot are read once per click | the duplicate reads can go without moving code; the log shows the same results with fewer IPC calls | 1-day log comparison |
| 3 | Introduce `HCDiagnosticsRecorder` as an object owned by the delegate: move the 47 `_last*`, 10 `_total*` and the history containers; replace the five-call epilogue with one `-recordSkip:(HCSkipReason)` call; replace the result strings with an enum plus a string table that keeps the **exact current log text**; take `updateMenuTitles` off the click path by marking the menu dirty and syncing in `menuWillOpen:` | the click path no longer touches AppKit; the report text is byte-identical (diff the Copy Diagnostics output before and after on a fixed history) | report diff, callback p50/p99 |
| 4 | Extract `HCPolicy` as pure functions, with an XCTest or a plain `clang` test binary run in CI over recorded `CGWindowList` dictionaries (from the existing log lines) | the classification rules become regression-tested without Accessibility trust | new unit tests in CI |
| 5 | Extract `HCAX` + `HCWindowList` + `HCFocusEngine` | the focus engine is callable from a test harness (for example `tools/focus-observer.mm`) without the menu | the safety gate (no event APIs outside the tap file), a runtime log comparison on the 2026-09-21 Google Docs scenario (#52-#63, #84, #89) |
| 6 | Extract `HCEventTap` and `HCClickPipeline`; the delegate shrinks to wiring | the invariants live in one auditable file of under about 200 lines | the gate's "single tap file" rule, a full runtime matrix from `docs/TEST_MATRIX.md` |

### 7.3 Order rationale and the pending patch

The leaves go first. Stages 2 and 3 run before any file move, because they cut the hot path and the coupling while everything still sits in one diffable file. The invariant-bearing code (tap + callback) moves last, after the gate already enforces it across files.

The other chat's patch to `nonNormalTopWindowSkipReasonForWindowInfo:` (4642-4679), its call site (4069-4074) and the new `applicationLooksLikeMenuBarUtility:` next to `windowInfoLooksLikeCompactOverlay:` (4843) must land before stage 4, which moves exactly those lines into `HCPolicy`.