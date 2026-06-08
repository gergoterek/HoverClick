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
6. Attempts app activation, AX frontmost, `AXRaise`, and focused-window attributes.
7. Logs immediate front-app verification.
8. Returns the original event unchanged.

`observed leftMouseDown` from Phase 1 was only event observation. Phase 2 success requires target resolution plus a focus/raise action result.

Diagnostics intentionally remain verbose at this checkpoint. Logs distinguish click receipt, AX element lookup, target pid/app/window resolution, ignored targets, `AXRaise`, app activation, immediate verification, event pass-through, tap disabled/re-enabled, and tap removal. Each click now carries a monotonically increasing sequence id such as `click #42`.

Delayed verification has been removed from runtime. Stable Left Click Focus does not schedule timers, callbacks, synthetic clicks, cursor movement, or hover-assist-like work after the immediate focus attempt.

## Phase 3: Hover Focus Removal

The earlier optional Hover Focus experiment has been removed. HoverClick is not an AutoRaise-style app and must not focus, raise, or activate windows merely because the pointer moves over them.

The stable Phase 3 behavior is:

1. The event tap observes click-down triggers only: `kCGEventLeftMouseDown` and `kCGEventRightMouseDown`.
2. Mouse movement is not tapped for focus behavior.
3. A left click may trigger the existing click-to-focus path when Left Click Focus is on.
4. A right click may trigger the same safe focus path only when Right Click Focus is on.
5. The original click event is returned unchanged.
6. No synthetic clicks, cursor movement, window movement, or window resizing are performed.

The old persisted Hover Focus defaults key is intentionally no longer read, so an existing saved setting cannot re-enable mouse-move-to-focus behavior.

## Stable And Experimental Paths

Stable Left Click Focus is the normal behavior and defaults ON. It focuses, raises, and activates a background window immediately before the original left-click event is delivered, then returns that original event unchanged.

Right Click Focus is an independent trigger and defaults OFF. It persists under `rightClickFocusEnabled`; when OFF, right-click events are returned unchanged without running the focus path. When ON, right-clicking a valid background window uses the same target-window filters, app activation, AX frontmost, `AXRaise`, and immediate verification path as Left Click Focus, then returns the original right-click event unchanged so context menus remain normal.

Experimental Hover Click Assist is a separate feature flag under the `Hover` submenu. It defaults OFF and persists under `hoverClickAssistEnabled`, but the submenu and child toggle are enabled only while Left Click Focus is on. Turning Left Click Focus off does not overwrite the stored Hover Click Assist preference; turning Left Click Focus back on restores the previous checked or unchecked state. The effective assist state is `leftClickFocusEnabled && hoverClickAssistEnabled`. In this checkpoint it is an explicit no-op placeholder: ON or OFF, it does not schedule delayed verification, synthesize clicks, move the cursor, post replacement mouse events, or observe mouse movement. While effectively OFF, HoverClick logs that no assist path was scheduled.

## OS Integration

Launch at Login is a menubar-only integration that uses `SMAppService.mainAppService` on macOS 13 and newer. It registers or unregisters the main app as the login item; no helper app is bundled, and the toggle does not change event tap, focus, hover assist, Accessibility, signing, or bundle identity behavior.

The status menu starts with one non-clickable custom header row: `HoverClick` on the left and `v<short-version> (<build>)` on the right. The version label reads from `CFBundleShortVersionString` and `CFBundleVersion` in the main bundle at runtime, with generic fallbacks only for malformed bundle metadata. The header tooltip is a one-sentence summary of the current version.

Feature toggles use stable titles with native macOS checked/unchecked menu item state rather than appending `On` or `Off` to the title. Left Click Focus and Right Click Focus stay at the top level. Hover-related controls live under the `Hover` submenu, which is disabled when Left Click Focus is off. Permission and login/startup items live under the `Permissions & Startup` submenu to keep the top-level menu compact; that submenu ends with `Open Accessibility Settings` as an explicit user-click action. Submenu parent items do not carry tooltips, while child status/action items keep specific native `NSMenuItem` tooltip/help text. Technical runtime details such as click detection state and last handled action are not persistent menu rows; they are available through `Diagnostics` > `Copy Diagnostics Summary`. Custom tracking loops, focus-stealing help windows, hover timing controls, or hover event monitors should remain separate future work if native menu tooltips prove insufficient.

Intentional shipped behavior or UI changes should bump `CFBundleShortVersionString` and `CFBundleVersion`. Git checkpoint-only tasks, read-only audits, and docs-only tasks should not bump the visible app version unless they affect shipped behavior or UI.

## Phase 4: DMG

Package the app for normal local installation and distribution after the identity and runtime behavior are stable.

## Future Planned Triggers

Scroll Focus is a planned future trigger type, but it is not part of this stabilization pass. It should be implemented only after the stable click core has been confirmed.

Future menus should expose controls for each trigger/action type:

- Left Click Focus
- Right Click Focus
- Scroll Focus
- Hover > Hover Click Assist

Until a scroll phase is deliberately started, the event tap should continue to observe only the current stable click inputs: `kCGEventLeftMouseDown` and `kCGEventRightMouseDown`.

## Phase 5: Experimental Hover Click Assist

Explore click-time assistance for hover-dependent UI elements after a window switch. Experimental Hover Click Assist must not focus windows from mouse movement alone, and it uses distinct naming from the removed Hover Focus experiment.
