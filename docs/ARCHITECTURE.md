# Architecture

## Phase 0: Signed Menubar Shell

Create a stable, signed, menubar-only app bundle with a fixed bundle identifier and an Accessibility permission status check.

## Phase 1: Event Tap Permission Proof

Implemented a minimal listen-only `CGEventTap` proof for `kCGEventLeftMouseDown`. It validates Accessibility permission and event tap lifecycle behavior without changing click delivery, focusing windows, raising windows, or synthesizing events.

## Phase 2: Fast Click-To-Focus

Implemented fast click-to-focus behavior. The event tap now uses a pass-through default tap for `kCGEventLeftMouseDown` so HoverClick can attempt focus before returning the original event unchanged.

The callback remains pass-through: it never returns a replacement click event and never returns `NULL` for normal clicks. `NULL` is returned only for system tap-disabled pseudo-events. HoverClick does not synthesize clicks, move the cursor, move windows, or resize windows.

For each click, HoverClick:

1. Reads the global click point from `CGEventGetLocation`.
2. Uses `AXUIElementCreateSystemWide` and `AXUIElementCopyElementAtPosition` to resolve the element under the cursor.
3. Reads the target pid and app name.
4. Ignores HoverClick itself, menu roles, status items, and unresolved targets.
5. Resolves a target window from `AXWindow` or by climbing `AXParent`.
6. Attempts `AXRaise`, app activation, and focused-window attributes.
7. Logs immediate and delayed front-app verification.
8. Returns the original event unchanged.

`observed leftMouseDown` from Phase 1 was only event observation. Phase 2 success requires target resolution plus a focus/raise action result.

Diagnostics intentionally remain verbose at this checkpoint. Logs distinguish click receipt, AX element lookup, target pid/app/window resolution, ignored targets, `AXRaise`, app activation, immediate verification, delayed verification, event pass-through, tap disabled/re-enabled, and tap removal.

## Phase 3: Stable Menubar Controls

Add reliable controls for enabling, disabling, diagnostics, and future tuning.

## Phase 4: DMG

Package the app for normal local installation and distribution after the identity and runtime behavior are stable.

## Phase 5: Experimental Hover Assist

Explore hover-based assistance separately from the click-to-focus core, behind explicit controls.
