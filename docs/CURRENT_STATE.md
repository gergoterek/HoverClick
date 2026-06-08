# Current State

## Identity

- Project name: `HoverClick`
- Project path: `/Users/gergoterek/Movies/OBS/GPT/HoverClick`
- App name: `HoverClick`
- Bundle identifier: `com.gergoterek.HoverClick`
- Signing identity: `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`

## Commands

- Build: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh`
- Verify: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh`
- Manual run: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh`

`scripts/run-app.sh` launches the signed `.app` bundle with `/usr/bin/open`. Do not run it during automated Codex validation unless the user explicitly asks for a manual UI test.

## Forbidden Commands And Actions

- Do not run the raw binary at `HoverClick.app/Contents/MacOS/HoverClick`.
- Do not run `scripts/run-app.sh` automatically during build or verification tasks.
- Do not use `sudo`, `tccutil reset`, ad-hoc signing, `codesign -`, or `CODE_SIGN_IDENTITY=""`.
- Do not change the app name, bundle identifier, signing identity, `Info.plist` identity fields, Makefile signing behavior, Accessibility/TCC flow, or event tap behavior unless fixing a confirmed behavior bug.
- Do not automate Finder, System Settings, keyboard, mouse, clipboard, Accessibility UI, or macOS app focus during validation.
- Do not use `open`, `open -R`, `osascript`, AppleScript, JXA, Automator, Shortcuts, Finder reveal/select, or System Events UI scripting during automated work.

## Implemented Features

- Menubar-only accessory app with status item and menu controls.
- Accessibility permission status display and refresh.
- Event tap lifecycle management with duplicate-install guard and disabled/re-enable logging.
- Left Click Focus, enabled by default and toggleable from the menu.
- Right Click Focus, disabled by default and toggleable independently from Left Click Focus.
- Pass-through left mouse down handling: the original click event is returned unchanged for normal clicks.
- Pass-through right mouse down handling: when Right Click Focus is on, the target background window is focused before the original right-click event continues unchanged.
- AX target resolution from the click point, bounded parent climbing to find a window, target app/window logging, menu/status/transient UI ignores, app activation, AX frontmost, `AXRaise`, focused-window attribute attempts, and immediate verification.
- Verbose diagnostics and click sequence ids.
- Launch at Login via the ServiceManagement main-app login item API on macOS 13 and newer.
- Experimental Hover Click Assist is present as an independent default-off no-op feature flag.

## Removed Features

- AutoRaise-style Hover Focus has been removed.
- Mouse movement is not tapped for focus behavior.
- The old persisted `HoverFocusEnabled` defaults key is not read, so an old setting cannot re-enable hover-to-window-focus.

## Planned Future Features

- Phase 4: DMG packaging after identity and runtime behavior remain stable.
- Future trigger idea: Scroll Focus.
- Future trigger work must keep independent controls and should not change the stable left-click or right-click core casually.

## Event Tap

- Current event tap mask: `CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)`.
- `kCGEventMouseMoved` and scroll events are not observed.
- Normal tap callback behavior returns the original event unchanged. `NULL` is returned only for system tap-disabled pseudo-events or a null incoming event.

## Permission And Signing Rules

- Accessibility permission belongs to the signed app bundle identity.
- Always launch as the signed `HoverClick.app` bundle, not the raw binary.
- Stable signing is required; ad-hoc signing is not acceptable for this project.
- Accessibility is required for the event tap and AX focus behavior.
- Missing Accessibility should leave the app open, keep the event tap uninstalled, show `Event Tap: Permission Missing`, and avoid repeated prompts or custom permission alerts.
- No Screen Recording, Input Monitoring, or additional permission is currently required.

## Stable Behavior

- HoverClick does not focus, raise, or activate windows from pointer movement alone.
- With Event Tap enabled and Left Click Focus on, a left click on a background window may focus the target before click delivery.
- With Event Tap enabled and Right Click Focus on, a right click on a background window may focus the target before the original right-click continues and the normal context menu works.
- Already-frontmost targets, HoverClick itself, menu/status UI, popovers, and front-app sheets/dialogs are ignored safely.
- Clicks, right-click context menus, drags, and normal macOS interactions should remain unchanged apart from the pre-click focus attempt.
- HoverClick does not synthesize mouse events, move the cursor, move windows, resize windows, or create a DMG.

## Known Non-Goals

- No scroll focus in the current phase.
- No hover-to-window-focus in the current phase.
- No active Hover Click Assist implementation yet; the current toggle is a no-op placeholder.
- No DMG creation in the current Phase 3 stabilization state.

## Next Safe Step

Keep this stable baseline unchanged. The next safe feature is Scroll Focus in a separate Codex chat, with its own design and validation pass.

## Manual Test Checklist

Manual Finder UI validation -- not run automatically.

- Launch `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh` only when a manual UI test is intended.
- Confirm the app appears as a menu bar status item.
- Confirm Accessibility status shows `Granted` or `Missing` correctly.
- With Accessibility granted, confirm Event Tap can enable and disable from the menu.
- Move the pointer over background Finder, Chrome, and iTerm windows without clicking; no focus change should occur.
- With `Left Click Focus: On`, click visible background Finder, Chrome, and iTerm windows; target focus should occur before the original click passes through.
- With `Right Click Focus` checked, right-click visible background Finder, Chrome, and iTerm windows; target focus should occur before the original right-click passes through and the normal context menu works.
- Click HoverClick status/menu UI and transient menu/popover UI; they should be ignored safely.
- Drag windows, select text, and use sliders; drag behavior should remain unchanged.
- Review unified logs for click receipt, target resolution, action attempts, verification, and `event passed through`.

## Confirmed Manual Stable Checkpoint

Manual Finder UI validation -- not run automatically.

- Left Click Focus works.
- Right Click Focus works.
- Right Click Focus focuses the target background window first, then normal right-click/context menu behavior works.
- Launch at Login works.
- Mouse movement alone does not focus windows.
- Accessibility permission did not reappear.
- Original left-click and right-click events are returned unchanged.
- No synthetic click behavior, cursor movement, `CGEventPost`, `CGDisplayMoveCursorToPoint`, or `kCGEventMouseMoved` exists.
