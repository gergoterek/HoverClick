# Architecture

## Phase 0: Signed Menubar Shell

Create a stable, signed, menubar-only app bundle with a fixed bundle identifier and an Accessibility permission status check.

## Phase 1: Event Tap Permission Proof

Implemented a minimal listen-only `CGEventTap` proof for `kCGEventLeftMouseDown`. It validates Accessibility permission and event tap lifecycle behavior without changing click delivery, focusing windows, raising windows, or synthesizing events.

## Phase 2: Fast Click-To-Focus

Implemented fast click-to-focus behavior. The event tap now uses a pass-through default tap for `kCGEventLeftMouseDown` so HoverClick can attempt focus before returning the original event unchanged.

The callback remains pass-through: it never returns a replacement click event and never returns `NULL` for normal clicks. `NULL` is returned only for system tap-disabled pseudo-events. HoverClick does not synthesize clicks, move the cursor, move windows, or resize windows.

Event tap lifecycle guards:

- Installs only once and logs `event tap already installed; skipping duplicate install` when a duplicate install is requested.
- Logs `event tap disabled by timeout` or `event tap disabled by user input` for system-disabled pseudo-events.
- Re-enables the existing tap when the user still wants it enabled and logs `event tap re-enabled after ...`.
- Removes the run loop source and CFMach port on app quit or menu disable.
- Logs `event tap remove requested but no active tap` for no-op cleanup.

For each click, HoverClick:

1. Reads the global click point from `CGEventGetLocation`.
2. Uses `AXUIElementCreateSystemWide` and `AXUIElementCopyElementAtPosition` to resolve the element under the cursor.
3. Reads the target pid and app name.
4. Ignores HoverClick itself, menu roles, status items, and unresolved targets.
5. Resolves a target window from `AXWindow` or by bounded `AXParent` climbing.
6. Attempts `AXRaise`, app activation, and focused-window attributes.
7. Logs immediate and delayed front-app verification.
8. Returns the original event unchanged.

`observed leftMouseDown` from Phase 1 was only event observation. Phase 2 success requires target resolution plus a focus/raise action result.

Diagnostics intentionally remain verbose at this checkpoint. Logs distinguish click receipt, AX element lookup, target pid/app/window resolution, ignored targets, `AXRaise`, app activation, immediate verification, delayed verification, event pass-through, tap disabled/re-enabled, and tap removal. Each click now carries a monotonically increasing sequence id such as `click #42`, so delayed verification can be matched to the initiating click.

Delayed verification is asynchronous and capped so rapid clicks do not stack unbounded verification blocks. If the target app exits before delayed verification runs, HoverClick logs a stale target instead of treating it as a crash or false focus failure. If a newer click has occurred, delayed verification logs `newerClick=YES`.

## Phase 3: Optional Hover Focus

Implemented a minimal optional Hover Focus toggle. Hover Focus is OFF by default, persists with `NSUserDefaults`, and is independent from Click-to-Focus.

Hover Focus uses the same event tap and focus pipeline:

1. The event tap also observes `kCGEventMouseMoved`.
2. Mouse move events always pass through unchanged.
3. When Hover Focus is OFF, mouse movement does no AX lookup.
4. When Hover Focus is ON, the latest pointer location is stored and a 250 ms debounce is scheduled.
5. If the pointer moves more than 6 px, the pending hover candidate is replaced.
6. After the delay, HoverClick resolves the AX element under the pointer using the same target resolution helpers as Click-to-Focus.
7. The same ignore rules, `AXRaise`, focused-window attributes, app activation, and delayed verification are used.
8. Same-target hover refocus is suppressed for 750 ms to avoid focus spam while the pointer stays in place.

Hover Focus does not synthesize clicks, consume mouse movement, move the cursor, move windows, or resize windows. Event Tap OFF disables both click-to-focus and hover-to-focus globally.

## Phase 4: DMG

Package the app for normal local installation and distribution after the identity and runtime behavior are stable.

## Phase 5: Experimental Hover Assist

Explore hover-based assistance separately from the click-to-focus core, behind explicit controls.
