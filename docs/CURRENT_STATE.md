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
- Pass-through left mouse down handling: the original click event is returned unchanged for normal clicks.
- AX target resolution from the click point, bounded parent climbing to find a window, target app/window logging, menu/status/transient UI ignores, `AXRaise`, app activation, focused-window attribute attempts, and immediate plus delayed verification.
- Verbose diagnostics, click sequence ids, stale-target delayed verification handling, and a cap on pending delayed verifications.

## Removed Features

- AutoRaise-style Hover Focus has been removed.
- Mouse movement is not tapped for focus behavior.
- The old persisted `HoverFocusEnabled` defaults key is not read, so an old setting cannot re-enable hover-to-window-focus.

## Planned Future Features

- Phase 4: DMG packaging after identity and runtime behavior remain stable.
- Future trigger ideas: Right Click Focus, Scroll Focus, and possible Hover Click Assist.
- Future trigger work must keep independent controls and should not change the stable left-click core casually.

## Event Tap

- Current event tap mask: `CGEventMaskBit(kCGEventLeftMouseDown)` only.
- `kCGEventMouseMoved`, right-click, and scroll events are not currently observed.
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
- Already-frontmost targets, HoverClick itself, menu/status UI, popovers, and front-app sheets/dialogs are ignored safely.
- Clicks, drags, and normal macOS interactions should remain unchanged apart from the pre-click focus attempt.
- HoverClick does not synthesize mouse events, move the cursor, move windows, resize windows, or create a DMG.

## Known Non-Goals

- No right-click focus in the current phase.
- No scroll focus in the current phase.
- No hover-to-window-focus in the current phase.
- No Hover Click Assist implementation yet.
- No DMG creation in the current Phase 3 stabilization state.

## Next Safe Step

Keep Phase 3 stable. The next safe project step is documentation/test-matrix cleanup or manual validation of the existing signed `.app` behavior. Product work beyond that should move deliberately to Phase 4 packaging, without changing runtime focus behavior.

## Manual Test Checklist

Manual Finder UI validation -- not run automatically.

- Launch `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh` only when a manual UI test is intended.
- Confirm the app appears as a menu bar status item.
- Confirm Accessibility status shows `Granted` or `Missing` correctly.
- With Accessibility granted, confirm Event Tap can enable and disable from the menu.
- Move the pointer over background Finder, Chrome, and iTerm windows without clicking; no focus change should occur.
- With `Left Click Focus: On`, click visible background Finder, Chrome, and iTerm windows; target focus should occur before the original click passes through.
- Click HoverClick status/menu UI and transient menu/popover UI; they should be ignored safely.
- Drag windows, select text, and use sliders; drag behavior should remain unchanged.
- Review unified logs for click receipt, target resolution, action attempts, verification, and `event passed through`.
