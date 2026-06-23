# Cross-Display Menu-Bar Click Assist — Research

## Status

Research-only. Not implemented. No production code changed.

Branch at investigation: `bugfix-multimonitor-menubar-click` / HEAD `0a8c62e`

## Root-Cause Confirmation

**Native macOS behavior. HoverClick is not the cause.**

Baseline test with HoverClick fully quit:

- Display A active app/window → single-click Display B menu bar: **FAIL** (first click does not trigger action)
- Display B active app/window → single-click Display A menu bar: **FAIL**

The same failure reproduces without HoverClick running. No HoverClick passthrough fix can address this. The investigation branch (`bugfix-multimonitor-menubar-click`) is therefore reclassified:

- **Old classification:** HoverClick event tap / passthrough bug
- **New classification:** Native macOS cross-display menu-bar activation limitation; research for an optional compensating feature

## Feature Name

**Cross-Display Menu-Bar Click Assist** (abbreviated **CDMBA** in this document)

## The Native macOS Behavior

macOS with **"Displays have separate Spaces"** (System Settings → Desktop & Dock) gives each connected display its own menu bar showing the frontmost app for that display's Space. The first click on another display's menu bar does not directly trigger the menu action. Instead, macOS performs a *display context activation* step — approximately 1 second of state transition — before that display's menu bar becomes responsive. The user's first click is consumed by the activation phase and the intended action is lost.

This is a two-phase state machine:

```
Phase 1: first click on other display's menu bar
  → macOS: transfer active Space / display context
  → result: the other display's menu bar is now "live"
  → user's original click: consumed for activation only, action discarded

Phase 2: second click on same location
  → macOS: menu bar is now active, action executes
  → result: menu opens / status item triggers
```

Window activation across displays does not share this problem: macOS can activate the app behind a window click fast enough that the first click serves as both activator and action. Menu-bar activation takes longer because it requires a broader display-context transition, not just app-focus.

## Feature Goal

When HoverClick detects a left-click on a different display's menu bar than the one currently associated with the active app, compensate for the native two-phase activation by triggering the intended menu-bar action *after* the display context activates, so the user's first click achieves the intended result without a second click.

## Scope

- Left clicks on menu bar / top strip of any connected display only
- Must be explicitly opt-in (experimental toggle, defaults **off**)
- Modifier-assisted mode is an additional risk-reduction option (see below)
- Right Click Focus: out of scope for CDMBA; right-clicks on the menu bar are already passed through
- Auto-hide menu bar: detection must still use the existing `effectiveMenuBarHeight` logic

## Non-Goals For This Research

- No change to normal (same-display) click behavior
- No hover-to-focus, no mouseMoved tap, no scroll tap
- No changes to Info.plist, signing, bundle ID, Sparkle, appcast, or release assets
- No version/build bump during research
- No merge to main during research

---

## Detection: Identifying a Cross-Display Menu-Bar Click

### What Is Already Known at Click Time

`pointIsInScreenMenuBarArea:` (in the current fast path) already:

1. Identifies which `NSScreen` the click lands on (the *click screen*)
2. Computes the menu-bar strip height for that screen
3. Confirms the click is inside the top strip

What it does **not** know: whether the click screen is the screen that currently "owns" the active app's context.

### Determining the Active Display

The active display is the one hosting the frontmost app's focused window. To identify it:

**Option A — CGWindowList (already used in the normal click path):**
- `[NSWorkspace sharedWorkspace].frontmostApplication.processIdentifier` → target PID
- `CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID)` → filter to PID, find the on-screen window with layer 0 and largest area
- Convert window `kCGWindowBounds` origin to AppKit coordinates → look up matching screen

Cost: one `CGWindowListCopyWindowInfo` call (same IPC cost as `topmostWindowInfoAtPoint:`). Acceptable for an experimental opt-in feature. **Not acceptable on the existing ultra-fast menu-bar fast path.**

**Option B — AX focused window:**
- `AXUIElementCreateApplication(frontmostPID)` → `kAXFocusedWindowAttribute` → `kAXPositionAttribute`
- Match position to an `NSScreen`

Cost: two AX IPC calls. Slightly heavier than Option A but more reliable when a window spans multiple screens.

**Recommended for prototype:** Option A. It is consistent with the CGWindowList usage already present for overlay detection.

**Heuristic shortcut (lower accuracy):** If the click screen is `NSScreen.screens.firstObject` (the screen where `NSScreen.mainScreen` is), assume it might be active. This is only appropriate for a first-pass feasibility probe, not for a shipped feature.

### Cross-Display Decision

```
isCrossDisplayMenuBarClick =
    pointIsInScreenMenuBarArea(axPoint)             // click is in menu bar
    && clickScreen != nil                           // a screen matched
    && activeAppScreen != nil                       // frontmost app has a resolvable screen
    && clickScreen != activeAppScreen               // they are different displays
```

Edge cases:
- Frontmost app is on both screens (window straddles displays): treat as same-display, skip assist
- No frontmost app (Finder or bare desktop): assist may still apply; Finder is on some screen
- Single monitor: `activeAppScreen == clickScreen` always → assist never fires
- Displays have separate Spaces OFF: per-display menu bars do not exist; first click behaves like a normal same-display click → assist is unnecessary and should not fire

---

## Approach 1: AX Press Action (No Synthetic Click)

### Concept

After HoverClick's event tap returns the original menu-bar click unchanged — allowing macOS to perform its display-context activation — HoverClick fires a `dispatch_after` on the main queue with a configurable delay. When it fires, it uses `AXUIElementCopyElementAtPosition` at the original click coordinates to find the menu-bar element and calls `kAXPressAction` on it.

### Code Shape

```objc
// In handleLeftMouseDown:, after pointIsInScreenMenuBarArea: returns YES
// and cross-display detection confirms isCrossDisplayMenuBarClick:

_lastCDMBAClickPoint = rawPoint;
_lastCDMBAClickTime = now;

// Return original event to macOS (display activates)

// On main queue, after activation window:
dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
    (int64_t)(_cdmbaDelaySeconds * NSEC_PER_SEC)),
    dispatch_get_main_queue(), ^{
    if (now - _lastCDMBAClickTime > _cdmbaExpireSeconds) { return; }
    CGPoint clickPoint = _lastCDMBAClickPoint;
    AXUIElementRef element = [self copyElementAtAccessibilityPoint:clickPoint];
    if (element == NULL) { return; }
    AXError pressErr = AXUIElementPerformAction(element, kAXPressAction);
    CFRelease(element);
    // Record diagnostic; do not retry
});
```

### Coverage

| Menu bar area | AX accessible? | CDMBA Approach 1 works? |
|---|---|---|
| App menus (File, Edit, View …) | Yes — `AXMenuBarItem` role, press action supported | **Yes** |
| Apple menu (top-left) | Typically yes via AX | **Likely** |
| System status icons (clock, battery, Wi-Fi, Bluetooth, Spotlight, Siri) | Variable; some respond to press, others do not | **Partial** |
| Third-party status items (Bartender, 1Password, Dropbox, etc.) | No — these are independent `NSStatusItem` windows, not in the AX menu bar tree | **No** |
| Menu extras / menulets | No AX press path | **No** |

### Timing

The delay must allow macOS to complete display-context activation. Based on the user's observation ("about 1 second"), the delay window is roughly 200–800 ms. Testing at multiple values (200 ms, 350 ms, 500 ms) is required. Too short → AX press fires before the menu bar is active, no effect or wrong target. Too long → user experience degrades.

Expiry: if the cursor has moved significantly (more than ~40 pt) by the time the delay fires, the click intent has likely changed. Cancel the AX press. Use `NSEvent.mouseLocation` at dispatch time vs. at click time.

### Risks and Limits

- Does not work for third-party status items (the most common menu-extra targets). Covers only app menu bar items and partial system controls.
- AX press on a menu bar item does not guarantee a menu opens in the foreground. Some items trigger background actions.
- Incorrect timing may double-action an app menu (if macOS already processed the click somehow).
- This approach shares the AX IPC cost path already present in the normal focus path. No new categories of API.
- Does **not** require adding synthetic click, event replay, or CGEventPost. All existing safety invariants hold.

### Safety Classification

**Low additional risk.** AX action on a dispatched main-queue block is similar in principle to the existing delayed verification path. No new event types, no synthetic clicks, no cursor movement. Full opt-in experimental toggle required.

---

## Approach 2: Timer-Triggered Synthetic Re-Click (Experimental, Opt-In)

### Concept

After returning the original event unchanged, HoverClick posts a new synthetic `kCGEventLeftMouseDown` (and matching `kCGEventLeftMouseUp`) at the same raw click coordinates after a configurable delay.

### Why Synthetic Is Needed for Full Coverage

App menus and system controls are AX-accessible. Status items (third-party menu extras) are **not** in the AX menu bar tree. The only mechanism that reliably triggers any clickable element in the menu-bar strip — including status items — is delivering a hardware-equivalent mouse-down event to that position. No AX path covers this case.

### APIs Required

Currently forbidden APIs that CDMBA Approach 2 would require:

| API | Current status | Required for Approach 2 |
|---|---|---|
| `CGEventCreateMouseEvent` | Forbidden | Yes |
| `CGEventPost(kCGHIDEventTap, ...)` | Forbidden | Yes |
| `CGEventPost(kCGSessionEventTap, ...)` | Forbidden | Yes — alternative; does not go through HID tap, partially mitigates loop risk |

These are **explicitly listed as forbidden** in the current architecture. Enabling them for an opt-in experimental feature requires a deliberate design decision, documented here.

### Loop Prevention (Critical)

HoverClick's active event tap will intercept the synthetic click just like a real click. Without a guard, this creates an infinite loop:

```
User click → tap → detect cross-display → synthetic re-click →
tap → detect cross-display → synthetic re-click → …
```

Mitigation options:

**Option L1 — Suppress flag with timeout:**
Before `CGEventPost`, set `_suppressCDMBASyntheticClick = YES` and record `_cdmbaSyntheticPostTime`. In the event tap callback, for the menu-bar area fast path, if `_suppressCDMBASyntheticClick` is YES and elapsed time since `_cdmbaSyntheticPostTime` is within 250 ms, treat as "our own synthetic — skip without recording as cross-display." Clear the flag after use or after the timeout. **Preferred.**

**Option L2 — Tap disable window:**
Briefly disable the event tap before posting, re-enable after. Fragile: if the re-enable fails, HoverClick stops working entirely.

**Option L3 — `CGEventPost(kCGSessionEventTap, ...)` instead of `kCGHIDEventTap`:**
Session-level events are not re-intercepted by a HID-level tap. This removes the loop risk structurally. But session-level events may behave differently for menu-bar interaction (they bypass HID processing).

**Recommended:** L1 as primary, L3 as secondary experiment.

### Cursor Drift Guard

By the time the delay fires, the user may have moved the cursor. If the cursor is more than ~40 pt from the original click location, the synthetic click would land on a different menu item than intended. Cancel and record a diagnostic. Check `NSEvent.mouseLocation` at dispatch time.

### Mouse-Up Pairing

A mouse-down without a matching mouse-up leaves the system in an inconsistent dragging state. CDMBA Approach 2 must post both:

1. `kCGEventLeftMouseDown` at the menu-bar position
2. `kCGEventLeftMouseUp` at the same position immediately after (5–10 ms delay, or back-to-back)

HoverClick's tap only intercepts `kCGEventLeftMouseDown`, so the synthetic up does not re-enter the loop, but it is still delivered as a real event to the system.

### Timing Parameters

| Parameter | Suggested default | Notes |
|---|---|---|
| Activation delay | 300 ms | Configurable; must be measured per-machine |
| Expiry window | 3 s | If user does something else, cancel assist |
| Max cursor drift | 40 pt | Cancel if cursor has moved beyond this |

### Risks

- **Accidental double-action:** If macOS *does* process the original click somehow (e.g., on some OS versions or some apps), the synthetic click fires a second time. This could open a menu twice or trigger an item twice.
- **Timing sensitivity:** Incorrect delay fires before display activation (no effect) or long after it (user may have already clicked again).
- **Status item state:** A status item may have changed state between user's first click and the synthetic re-click (e.g., a music player track changed, a notification dismissed).
- **Focus interference:** If another focus or window action occurred between the original click and the synthetic re-click, the synthetic click may land on a window that has moved under the cursor.
- **Security concerns:** Synthetic mouse events can interact with security dialogs, password prompts, etc. CDMBA must not fire for any region outside the confirmed menu-bar strip.

### Safety Classification

**High risk. Must remain opt-in experimental with explicit user acknowledgment.** This approach requires adding currently-forbidden APIs and carries loop risk that the suppress-flag guard must handle correctly. A shipping bug here could cause HoverClick to repeatedly click menu items the user did not intend.

---

## Approach 3: Event Proxy Hold / Async Replay

### Concept

Use the `CGEventTapProxy` parameter to hold the original event and re-deliver it after macOS activates the display.

### Assessment: Not Feasible

`CGEventTapProxy` is only valid for the duration of the tap callback. `CGEventTapPostEvent(proxy, event)` must be called synchronously within the callback, not from a `dispatch_after` block. Returning `NULL` from the callback to "eat" the event and then calling `CGEventTapPostEvent` asynchronously is undefined behavior and will crash or have no effect after the callback returns.

There is no supported macOS API to hold a raw HID event and re-inject it asynchronously with the proxy mechanism. Approach 3 is **not feasible** and should not be prototyped.

---

## Modifier-Assisted Mode

### Concept

CDMBA only fires when the user holds a designated modifier key (e.g., **Option** or **Shift**) during the cross-display menu-bar click. This eliminates false positives: the user explicitly signals "I want click assist here."

### Detection

`CGEventGetFlags(event) & kCGEventFlagMaskAlternate` (Option) or `kCGEventFlagMaskShift` (Shift) in the event tap callback.

Option is the recommended modifier: it is rarely used unintentionally when clicking a menu bar, and macOS Option-clicks on menu bar items already have special semantics (alternative options in some menus), which would give the user a natural expectation that Option is a "modifier-click."

**Conflict risk with Option:** Option-clicking some status items has special meanings (e.g., Wi-Fi → detailed info; battery → details). If CDMBA intercepts an Option-click on those items on a cross-display menu bar, it would interfere. This is an important caveat for the modifier choice.

**Shift** is safer as a trigger modifier but less intuitive.

**Alternative: Cmd** — holding Cmd while clicking a menu bar item typically does nothing useful, making it a safe modifier.

### Value

Modifier-assisted mode significantly reduces the risk surface compared to unconditional assist:

- No accidental same-display triggers (user must opt-in per click)
- No timing confusion
- No false positives on normal cross-display window clicks (which are not in the menu-bar strip anyway)
- Easy to test without disrupting normal workflows

### Recommendation

Implement modifier-assisted mode as the **first prototype step** before unconditional mode, regardless of which assist approach (AX or synthetic) is used.

---

## Prototype Path Recommendation

### Phase 0 (baseline, no code)

Confirm with the user:
1. Whether "Displays have separate Spaces" is enabled (likely yes, given the symptom)
2. Whether same-display menu bar first-click works normally (to isolate cross-display)
3. What categories of menu-bar items the user needs: app menus, system status, or third-party status items

If only app menus are needed → Approach 1 (AX) may be sufficient. If third-party status items are needed → Approach 2 (synthetic) will ultimately be required.

### Phase 1 (AX-only prototype, lower risk)

1. Add ivar `_cdmbaEnabled` (BOOL, defaults NO, persisted under a new defaults key)
2. Add opt-in experimental toggle to the Diagnostics submenu (not the Functions section — this keeps it clearly experimental/debug)
3. Implement cross-display detection using CGWindowList (Option A above)
4. In the menu-bar fast path, if cross-display is detected and `_cdmbaEnabled`, set `_lastCDMBAClickPoint` / time and schedule a `dispatch_after` at 300 ms
5. In the dispatch block: cursor drift check → `copyElementAtAccessibilityPoint:` → `kAXPressAction` → diagnostic write
6. Add CDMBA fields to Copy Diagnostics Summary (last CDMBA attempt, delay used, AX result, cursor drift check result)
7. Build, verify, run
8. Manual validation: app menus on cross-display (File, Edit menus) — does Approach 1 open them on first click with assist?

If Approach 1 covers the user's primary use case, stop here.

### Phase 2 (Synthetic re-click, experimental, only if Phase 1 insufficient)

1. Add a second deeper opt-in toggle `_cdmbaSyntheticEnabled` (defaults NO, requires `_cdmbaEnabled` also ON)
2. Add loop-prevention flag `_suppressCDMBASyntheticClick` with `_cdmbaSyntheticPostTime`
3. In the dispatch block after cursor drift check: post `CGEventLeftMouseDown` + `CGEventLeftMouseUp` with the suppress flag set
4. In the menu-bar fast path: check suppress flag → if set and within 250 ms window, treat as our own re-click, update diagnostic, clear flag, return early (not as a new cross-display click)
5. Extended manual validation:
   - App menus (File, Edit)
   - System status items (Wi-Fi, battery, clock)
   - Third-party status items (confirm with actual test cases)
   - Verify no infinite loop: check that sequence IDs advance by exactly 1 per original click and 1 for the synthetic re-post, never more
   - Verify normal same-display click behavior is unchanged
   - Verify HoverClick-to-HoverClick menu click works (its own menu is excluded by the existing menu role skip)

### Phase 3 (Modifier-only mode option)

If unconditional assist (Phase 1 or 2) has false positives in validation, add the modifier-assisted toggle as an alternative. This can be lower-urgency if Phase 1/2 validate well.

---

## Required New Fields / Ivars

```objc
// Cross-display menu-bar click assist
BOOL _cdmbaEnabled;                         // persisted toggle (defaults NO)
BOOL _cdmbaSyntheticEnabled;                // persisted secondary toggle (defaults NO)
CGPoint _lastCDMBAClickPoint;               // raw event coordinates of last CDMBA-detected click
CFAbsoluteTime _lastCDMBAClickTime;         // tap callback time of last CDMBA-detected click
NSString *_lastCDMBADescription;            // formatted diagnostic for Copy Summary
uint64_t _lastCDMBASequence;                // sequence ID of last CDMBA-detected click
BOOL _suppressCDMBASyntheticClick;          // loop-prevention flag (Approach 2 only)
CFAbsoluteTime _cdmbaSyntheticPostTime;     // time of last synthetic post (Approach 2)
uint64_t _totalCDMBAAttempts;              // counter: total assists attempted
uint64_t _totalCDMBASyntheticPosts;        // counter: synthetic re-clicks posted (Approach 2)
```

---

## Impact on Existing Invariants

| Invariant | Approach 1 (AX) | Approach 2 (Synthetic) |
|---|---|---|
| No synthetic clicks | **Preserved** | **Broken — must be opt-in experimental** |
| No event replay | Preserved | **Broken — must be opt-in experimental** |
| No CGEventPost | Preserved | **Broken — must be opt-in experimental** |
| No CGEventCreateMouseEvent | Preserved | **Broken — must be opt-in experimental** |
| Original event returned unchanged | Preserved | Preserved (original still passes through) |
| No cursor movement | Preserved | Preserved |
| No mouseMoved handling | Preserved | Preserved |
| Event tap mask: left+right down only | Preserved | Preserved |
| Left Click Focus can be disabled | Must be respected | Must be respected |
| App name, bundle ID, signing, Info.plist | Unchanged | Unchanged |

---

## Diagnostics Requirements

Any CDMBA implementation must add to Copy Diagnostics Summary:

```
Cross-display menu-bar assist: <enabled/disabled>
Cross-display menu-bar assist synthetic re-click: <enabled/disabled>
Last CDMBA detection: <left/right> #<seq> at <timestamp> raw=(<x>,<y>) 
                      click-screen=<screen-index> active-screen=<screen-index>
Last CDMBA assist attempt: <never | timestamp> delay=<ms> method=<AX/synthetic>
Last CDMBA AX result: <never | AXError name or success>
Last CDMBA cursor drift check: <never | delta=<pt> guard=<pass/fail>>
Last CDMBA synthetic post: <never | timestamp>
Last CDMBA suppress-flag use: <never | timestamp, elapsed>
CDMBA counters: attempts=<N> AX-successes=<N> synthetic-posts=<N> suppress-uses=<N>
```

---

## Open Questions Before Any Implementation

1. **Which display categories does the user primarily target?** App menus, system status, or third-party status items? The answer determines whether Approach 1 alone is sufficient.

2. **What exact activation delay does the user observe?** The "about 1 second" observation is useful, but measuring it precisely (via a timing diagnostic on a CDMBA probe commit) would let us pick the right dispatch delay.

3. **Is "Displays have separate Spaces" confirmed ON?** The feature is only relevant when this is on. If it is off, per-display menu bars do not exist and this assist is not needed.

4. **Does the user want modifier-assisted mode first** (lower risk, requires intentional per-click opt-in) or unconditional assist (higher risk, fires automatically on any cross-display menu bar click)?

5. **Which modifier is preferred** if modifier mode is used? Option (most natural, some conflicts with Option-click menu behavior), Shift (safe, less intuitive), or Command (safe, no standard menu bar conflicts)?

---

## Branch Strategy

Continue on `bugfix-multimonitor-menubar-click` for research/prototype. This branch name is now a misnomer (the original bug was confirmed native macOS, not a HoverClick bug), but it is an appropriate incubation branch for CDMBA research. A rename can be done if it causes confusion.

Do not merge to `main` until at least Phase 1 manual validation is complete and the feature is confirmed worthwhile.

---

## Decision Gate

After Phase 0 (answering the open questions above), choose exactly one prototype entry point:

| User target | Modifier first? | Entry point |
|---|---|---|
| App menus only | No | Phase 1 (AX only), unconditional |
| App menus only | Yes | Phase 1 (AX only), modifier-gated |
| Status items needed | Yes (recommended) | Phase 1 AX + modifier, then Phase 2 synthetic after AX validation |
| Status items needed | No | Phase 2 synthetic (riskier — not recommended as first step) |
