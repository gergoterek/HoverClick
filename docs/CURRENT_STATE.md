# Current State

## Identity

- Project name: `HoverClick`
- Project path: `/Users/gergoterek/Movies/OBS/GPT/HoverClick`
- App name: `HoverClick`
- Bundle identifier: `com.gergoterek.HoverClick`
- Signing identity: `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`
- Visible menu header: `HoverClick` with `v0.4.5` on the same row
- Diagnostics submenu version row: `Version 0.4.5 (31)`
- Bundle short version/build version: `0.4.5` / `31`

## Commands

- Build: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh`
- Verify: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh`
- Internal/test Apple Development signed DMG package: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh`
- Manual run: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh`

`scripts/run-app.sh` launches the signed `.app` bundle with `/usr/bin/open`. Do not run it during automated validation unless a manual UI test is explicitly requested.

## Current Distribution

- HoverClick is currently a GitHub/source-first macOS utility.
- The current public path is to clone the repository, build locally from source, run the signed `HoverClick.app` bundle, and grant Accessibility permission through System Settings.
- Apple Developer Program membership is not required for the current GitHub/source-first path.
- The internal/test DMG is Apple Development signed, not Developer ID signed, not notarized, and not a polished public installer.
- Future public DMG asset names should be simple, for example `HoverClick-0.4.5.dmg`; avoid public release asset names containing `-internal`.
- There is no notarized public DMG, Developer ID signed public binary, Mac App Store release, or signed `.pkg` installer.

## Current Product Behavior

- HoverClick is a menubar-only accessory app with no Dock icon.
- The menu bar icon uses the native template SF Symbol `cursorarrow.click`.
- The menu header shows `HoverClick` and the visible app version.
- `Left Click Focus` defaults on.
- `Right Click Focus` defaults off and is independent from left-click behavior.
- `Hover` contains `Hover Click Assist`.
- `Permissions & Startup` contains Accessibility status, Launch at Login, and `Open Accessibility Settings`.
- `Accessibility: Granted` shows a native menu checkmark when Accessibility permission is granted; `Accessibility: Not Granted` is unchecked.
- `Diagnostics` contains `Version 0.4.5 (31)`, `Verbose Diagnostics`, and `Copy Diagnostics Summary`.
- Technical click detection and last action details are available in the copied diagnostics summary.

## Stable Features

- Left-click focus: a left click on a background window can focus the target before the original click is delivered.
- Right-click focus: when enabled, a right click on a background window can focus the target before the original right-click continues.
- Finder context-menu follow-up left-click v2: after a recent Finder right-click that leaves Finder frontmost, the next left-click passes through before AX hit-testing so the context menu can dismiss and Finder can handle the click more natively.
- Overlay/menu-bar pass-through: if the topmost onscreen window under a click is non-layer-0, HoverClick skips AX background-window targeting so menu bar, status-item, overlay, and popover UI can receive the original click unchanged.
- Bartender/menu-bar overlay pass-through: expanded or overflow menu bar items remain protected by the same non-layer-0 top-window check.
- Background text first-drag limitation: HoverClick still returns the original mouse-down unchanged, but some apps may treat the first mouse-down that began while inactive as activation-only, so text selection/drag can require a second drag unless a future safe non-replay fix is proven.
- Launch at Login: uses the ServiceManagement main-app login item API on macOS 13 and newer.
- Diagnostics summary: copies app name, version/build, bundle identifier, permission, startup, click detection, feature state, Hover Click Assist setting and no-op runtime behavior, event tap requested/object/source/validity/installed/enabled state, last event tap callback, last left/right mouse-down timestamps, last recovery attempt/result, last handled action, last focus action/skip reason, persistent last background-focus trigger/target/frontmost-before/activation/AX-operation/immediate-frontmost/delayed-verification/result/failure details, last verified successful background focus, event tap mask, safety note, and concise known limitations.
- Diagnostics menu polish: visible runtime details stay out of the menu; `Copy Diagnostics Summary`, `Open Accessibility Settings`, and `Quit` use left-slot action icons with exactly 1 ASCII space of title padding, and Quit preserves Cmd+Q.
- Accessibility onboarding: available from `Permissions & Startup` > `Open Accessibility Settings`.

## v0.4.5 Release Readiness

v0.4.5 is a focused bugfix/stability release after v0.4.4. It includes the long-run click-loss / event tap lifecycle diagnostics and recovery work, clearer event tap requested/object/source/validity/installed/enabled/detected diagnostics, and persistent background focus diagnostics.

Delayed focus verification is included because immediate `NSWorkspace.frontmostApplication` verification can lag behind macOS activation. The delayed check is diagnostic-only and non-blocking.

Manual main validation passed for Chrome-to-Finder left-click and right-click background focus with activation attempted=yes, returnValue=yes, AX operations attempted:success, immediate frontmost remaining Chrome, delayed verification passing after 0.20s with Finder frontmost, result success, and verification delayed passed.

Post-release published DMG manual smoke validation passed for the GitHub v0.4.5 release asset `HoverClick-0.4.5.dmg`. The downloaded DMG SHA-256 matched `d13bf53cedea7658fd63d77995b6f73d9430de0f7ad26b961e14409b5f174c4c`; launch worked; the menu opened; version showed `0.4.5` / build `31`; Accessibility status was correct; Left Click Focus worked; Right Click Focus worked when enabled; diagnostics background-focus fields worked; Finder context-menu follow-up left-click worked; Bartender/menu-bar overlay pass-through worked; Copy Diagnostics Summary worked; and Quit/Cmd+Q worked.

The event tap mask remains left mouse down + right mouse down only. No synthetic clicks, event replay, cursor movement, mouse-move focus, scroll focus, `mouseDragged`/`mouseUp` handling, or `CGEventPost` were added. Hover Click Assist remains a no-op placeholder, not a real runtime feature.

## Experimental Or Placeholder Items

`Hover Click Assist` is an experimental placeholder. It defaults off, is disabled while Left Click Focus is off, and currently performs no synthetic click, cursor movement, replacement event, mouse-move focus behavior, or delayed assist behavior. Delayed verification, when present, belongs only to background-focus diagnostics after an immediate frontmost check fails.

## Non-Goals In The Current Build

- No AutoRaise-style hover-to-focus behavior.
- No mouse-move focus event tap.
- No Scroll Focus.
- No synthetic clicks.
- No cursor movement.
- No window movement or resizing.
- No Screen Recording permission.
- Internal/test Apple Development signed DMG packaging is available for local testing only. It is not Developer ID signed, not notarized, and not a polished public installer.

HoverClick currently does not add Scroll Focus because macOS already supports background scrolling in many apps. The current event tap observes only left and right mouse-down triggers.

## Finder Right-Click Actual Selection Limitation

- Finder may keep the previous actual selection while showing a separate context-target highlight for a right-clicked item.
- HoverClick does not currently force the right-clicked Finder item to become the actual selection.
- The safe Accessibility-only approach was not reliable.
- HoverClick should not use synthetic clicks, event replay, or cursor movement to force that behavior.

## Event Tap

- Current event tap mask: `CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)`.
- `kCGEventMouseMoved` and scroll events are not observed.
- Normal tap callback behavior returns the original event unchanged.
- System tap-disabled pseudo-events are not treated as normal mouse events.
- Disabled-by-timeout and disabled-by-user-input callbacks attempt to re-enable the existing tap when user intent is still enabled and the CFMachPort/run loop source are valid.
- If re-enable fails, or if the tap port/source is missing or invalid, HoverClick removes the stale objects and recreates the same left/right mouse-down-only event tap.
- The callback returns the incoming pseudo-event value for system tap-disabled pseudo-events, and returns `NULL` only when the incoming event is `NULL`.
- Copied diagnostics distinguish requested state, tap object/source presence, port/source validity, believed installed/enabled state, detected enabled state when available, the last callback type, last left/right mouse-down timestamps, last recovery attempt/result, the volatile last handled action, and persistent background-focus execution fields that include frontmost-before, activation return value, AX operation results, immediate verification, delayed verification, final result, failure reason, and success state that are not erased by later menu or overlay clicks.

## Permission And Signing Rules

- Accessibility permission belongs to the signed app bundle identity.
- Always launch as the signed `HoverClick.app` bundle, not the raw binary.
- Stable signing is required.
- Missing Accessibility should leave the app open and show `Accessibility: Not Granted`.
- No Screen Recording, Input Monitoring, or additional permission is currently required.

## Version Rule

- The visible menu version reads from `CFBundleShortVersionString`.
- The header displays the version as `v<short-version>`.
- The Diagnostics submenu displays `Version <short-version> (<build-version>)`.
- `CFBundleVersion` is an internal build number and is not shown in the compact header.
- Documentation-only tasks should not change app version fields.

## Development Workflow

- `main` is the stable baseline.
- Development work should use task branches.
- Use `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/checkpoint.sh` to build, verify, commit intentional changes, and push the current task branch.
- Merge task branches into `main` only after review and manual approval.

## Manual Test Checklist

Manual Finder UI validation -- not run automatically.

- Confirm the published GitHub v0.4.5 DMG smoke test result is recorded: downloaded `HoverClick-0.4.5.dmg`, SHA-256 `d13bf53cedea7658fd63d77995b6f73d9430de0f7ad26b961e14409b5f174c4c`, launched successfully, showed version `0.4.5` / build `31`, reported correct Accessibility status, passed left-click focus, passed right-click focus when enabled, copied diagnostics, preserved Finder context-menu follow-up left-click behavior, preserved Bartender/menu-bar overlay pass-through, and quit through the menu/Cmd+Q.
- Launch `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh` only when a manual UI test is intended.
- Confirm the app appears as a menu bar status item.
- Confirm the status menu shows `HoverClick` and `v0.4.5` on the same header row.
- Confirm `Left Click Focus` is checked by default.
- Confirm `Right Click Focus` is unchecked by default.
- Confirm `Permissions & Startup` contains Accessibility status, Launch at Login, and Open Accessibility Settings.
- Confirm `Hover` contains `Hover Click Assist`.
- Confirm `Diagnostics` contains `Version 0.4.5 (31)`, `Verbose Diagnostics`, and `Copy Diagnostics Summary`.
- Confirm `Copy Diagnostics Summary` uses a copy-style action symbol and does not show a checkmark.
- Confirm `Open Accessibility Settings` uses its action symbol and exactly 1 ASCII space of title padding.
- Confirm `Quit` uses one left-slot action symbol, exactly 1 ASCII space of title padding, and preserves Cmd+Q.
- Confirm `Copy Diagnostics Summary` includes the event tap lifecycle fields: requested, object exists, port valid, run loop source exists, run loop source valid, installed/enabled believed state, detected enabled state, last callback, last left/right mouse-down, last recovery attempt/result, last focus action/skip, last background-focus trigger/target/frontmost-before/activation/AX/immediate/delayed/final verification/failure reason, and last verified successful background focus.
- Move the pointer over background windows without clicking; no focus change should occur.
- With `Left Click Focus` checked, click visible background windows; target focus should occur before the original click passes through.
- With `Right Click Focus` checked, right-click visible background windows; target focus should occur before the original right-click passes through and the normal context menu works.
- Click HoverClick status/menu UI and transient menu/popover UI; they should be ignored safely.
- Drag windows, select text, and use sliders; drag behavior should remain unchanged.
- Copy diagnostics and confirm it includes app name, version/build, bundle identifier, permission, startup, feature states, expanded event tap lifecycle state, event tap mask, the safety note, and concise known limitations.
- Leave the app running for a longer period, including idle/sleep/wake or lock-unlock if practical. If left and right click focus stop together, copy diagnostics immediately and compare the requested/enabled/validity/recovery fields.
