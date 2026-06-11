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
- Tracks user intent, tap object presence, CFMachPort validity, run loop source presence, run loop source validity, believed installed state, and believed enabled state separately.
- Re-enables the existing tap when the user still wants it enabled, the CFMachPort is valid, and the run loop source is valid, then logs `event tap re-enabled after ...`.
- Recreates the tap when disabled-event recovery finds a missing or invalid port/source, or when `CGEventTapEnable` does not leave the tap enabled.
- Removes the run loop source and CFMach port on app quit or menu disable.
- Logs `event tap remove requested but no active tap` for no-op cleanup.

For each click, HoverClick:

1. Reads the global click point from `CGEventGetLocation`.
2. Uses `AXUIElementCreateSystemWide` and `AXUIElementCopyElementAtPosition` to resolve the element under the cursor.
3. Reads the target pid and app name.
4. Ignores HoverClick itself, menu roles, status items, and unresolved targets.
5. Resolves a target window from `AXWindow` or by bounded `AXParent` climbing.
6. Attempts app activation, AX frontmost, `AXRaise`, and focused-window attributes.
7. Records frontmost-before, activation return value, AX operation results, and immediate front-app verification.
8. If immediate verification fails, schedules a short main-queue delayed verification diagnostic.
9. Returns the original event unchanged.

`observed leftMouseDown` from Phase 1 was only event observation. Phase 2 success requires target resolution plus a focus/raise action result.

Diagnostics intentionally remain detailed. Logs distinguish click receipt, AX element lookup, target pid/app/window resolution, ignored targets, `AXRaise`, app activation, immediate verification, delayed verification when immediate verification fails, event pass-through, tap creation, tap enable/disable, tap disabled/re-enabled/recreated recovery, and tap removal. Each click carries a monotonically increasing sequence id such as `click #42`.

`Diagnostics` > `Copy Diagnostics Summary` exposes the event tap lifecycle state needed for long-running failures: requested state, object/source presence, port/source validity, believed installed/enabled state, detected enabled state when available, last event tap callback type, last left/right mouse-down callback timestamps, and last recovery attempt/result. It also separates volatile last click handling from persistent background-focus diagnostics, including the last background-focus attempt, trigger, target app, frontmost app before the attempt, activation return value, AX operation results, immediate frontmost app, delayed verification state, final result, failure reason, and last verified successful background focus. Later menu or overlay clicks may update the volatile last handled action, but they do not erase the last background-focus attempt or last verified background-focus success.

Delayed verification is diagnostic-only and runs only after immediate frontmost verification fails. It is scheduled on the main queue after the original event has been left unmodified; it does not sleep in the event tap callback, consume the event, synthesize clicks, replay events, move the cursor, or add hover-assist-like work.

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

Right Click Focus is an independent trigger and defaults OFF. It persists under `rightClickFocusEnabled`; when OFF, right-click events are returned unchanged without running the focus path. When ON, right-clicking a valid background window uses the same target-window filters, app activation, AX frontmost, `AXRaise`, immediate verification, and diagnostic delayed verification path as Left Click Focus, then returns the original right-click event unchanged so context menus remain normal.

Finder context-menu follow-up handling is intentionally narrow. After a recent Finder right-click, if Finder is already frontmost when the next left-click arrives, HoverClick clears the short-lived Finder state and passes that left-click through before AX hit-testing, focusing, raising, or activation. This helps Finder context menus dismiss and lets Finder handle the follow-up click as natively as possible without synthetic click replay. HoverClick still does not force Finder actual selection; Finder may show a context-target highlight on right-click while keeping the previous actual selection.

Experimental Hover Click Assist is a separate feature flag under the `Hover` submenu. It defaults OFF and persists under `hoverClickAssistEnabled`, but the submenu and child toggle are enabled only while Left Click Focus is on. Turning Left Click Focus off does not overwrite the stored Hover Click Assist preference; turning Left Click Focus back on restores the previous checked or unchecked state. The effective assist state is `leftClickFocusEnabled && hoverClickAssistEnabled`. In the current build it is an explicit no-op placeholder: ON or OFF, it does not synthesize clicks, move the cursor, post replacement mouse events, observe mouse movement, or schedule delayed assist behavior. Copied diagnostics therefore reports the saved setting separately from the runtime behavior, which remains a no-op placeholder. While effectively OFF, HoverClick logs that no assist path was scheduled.

## OS Integration

Launch at Login is a menubar-only integration that uses `SMAppService.mainAppService` on macOS 13 and newer. It registers or unregisters the main app as the login item; no helper app is bundled, and the toggle does not change event tap, focus, hover assist, Accessibility, signing, or bundle identity behavior.

The status item uses a native template SF Symbol, `cursorarrow.click`, configured at 16 pt semibold/large scale inside a 23 pt `NSStatusItem`. The symbol remains vector-backed and template-tinted by AppKit for normal light/dark menu bar appearance. The implementation avoids custom status windows, event monitors, or private menu bar APIs.

The status menu starts with one non-clickable custom header row: `HoverClick` on the left and `v<short-version>` on the right. Both labels use a disabled text color; the custom view uses a compact 24 pt height, starts at indentation level 0, and uses a shared 14 pt horizontal padding constant so the title's left margin matches the version label's right margin. The visible header version reads only from `CFBundleShortVersionString` in the main bundle at runtime, with a generic fallback only for malformed bundle metadata. The Diagnostics submenu includes a disabled `Version <short-version> (<build-version>)` row for low-clutter build visibility. `CFBundleVersion` remains an internal build number and is not shown in the compact header. The header tooltip is a one-sentence specific changelog label for the current change/version area, using an area prefix such as `UI-Menubar:`, `Focus:`, `Permissions:`, or `Packaging:`.

Feature toggles use stable titles with native macOS checked/unchecked menu item state rather than appending `On` or `Off` to the title. Left Click Focus and Right Click Focus stay at the top level. Hover-related controls live under the `Hover` submenu, which is disabled when Left Click Focus is off. Permission and login/startup items live under the `Permissions & Startup` submenu to keep the top-level menu compact; that submenu ends with `Open Accessibility Settings` as an explicit user-click action. Submenu parent items do not carry tooltips, while child status/action items keep specific native `NSMenuItem` tooltip/help text. Non-toggle rows are kept at indentation level 0 with an off state; `Copy Diagnostics Summary`, `Open Accessibility Settings`, and `Quit` use left-slot action symbols with exactly 1 ASCII space of title padding, and Quit preserves Cmd+Q. Native AppKit menus may still reserve a shared checkmark gutter inside menus that contain checked toggle rows, and HoverClick avoids fragile all-custom menu workarounds. Technical runtime details such as click detection state and last handled action are not persistent menu rows; they are available through `Diagnostics` > `Copy Diagnostics Summary`. Custom tracking loops, focus-stealing help windows, hover timing controls, or hover event monitors should remain separate future work if native menu tooltips prove insufficient.

Intentional shipped behavior or UI changes should bump `CFBundleShortVersionString` and/or `CFBundleVersion` consistently with the scope of the change. Git checkpoint-only tasks and read-only audits should not change the visible app version or header tooltip. Docs-only tasks should not change the visible app version or header tooltip unless they intentionally document a shipped version-label change.

## Distribution Packaging

HoverClick is currently distributed as a GitHub/source-first macOS utility: clone the repository, build locally from source, run the signed `HoverClick.app` bundle, and grant Accessibility permission through System Settings.

`scripts/package-dmg.sh` is only an internal/test DMG workflow. It uses the current Apple Development signing identity, is useful for local/internal testing, is not notarized, and is not a polished public installer.

Future public DMG asset names should be simple, such as `HoverClick-0.4.5.dmg`; avoid public release asset names containing `-internal`.

Developer ID signing, notarization, stapling, a Mac App Store release, and a signed `.pkg` installer are not part of the current architecture. They remain optional future distribution work.

## Trigger Scope

HoverClick currently focuses windows only from configured click-down triggers. It does not add Scroll Focus because macOS already supports background scrolling in many apps.

Current menu controls expose:

- Left Click Focus
- Right Click Focus
- Hover > Hover Click Assist

The event tap should continue to observe only the current stable click inputs: `kCGEventLeftMouseDown` and `kCGEventRightMouseDown`.

## Experimental Hover Click Assist

Hover Click Assist is present as a default-off experimental placeholder for possible future hover-dependent button assistance. It is not part of the stable click-to-focus core, does not focus windows from mouse movement alone, and currently performs no cursor movement, synthetic click, replacement event, delayed assist behavior, or mouse-move behavior.
