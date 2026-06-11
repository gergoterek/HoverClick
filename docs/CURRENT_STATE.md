# Current State

## Identity

- Project name: `HoverClick`
- Project path: `/Users/gergoterek/Movies/OBS/GPT/HoverClick`
- App name: `HoverClick`
- Bundle identifier: `com.gergoterek.HoverClick`
- Signing identity: `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`
- Visible menu header: `HoverClick` with `v0.4.4` on the same row
- Diagnostics submenu version row: `Version 0.4.4 (30)`
- Bundle short version/build version: `0.4.4` / `30`

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
- `Diagnostics` contains `Version 0.4.4 (30)`, `Verbose Diagnostics`, and `Copy Diagnostics Summary`.
- Technical click detection and last action details are available in the copied diagnostics summary.

## Stable Features

- Left-click focus: a left click on a background window can focus the target before the original click is delivered.
- Right-click focus: when enabled, a right click on a background window can focus the target before the original right-click continues.
- Finder context-menu follow-up left-click v2: after a recent Finder right-click that leaves Finder frontmost, the next left-click passes through before AX hit-testing so the context menu can dismiss and Finder can handle the click more natively.
- Overlay/menu-bar pass-through: if the topmost onscreen window under a click is non-layer-0, HoverClick skips AX background-window targeting so menu bar, status-item, overlay, and popover UI can receive the original click unchanged.
- Bartender/menu-bar overlay pass-through: expanded or overflow menu bar items remain protected by the same non-layer-0 top-window check.
- Background text first-drag limitation: HoverClick still returns the original mouse-down unchanged, but some apps may treat the first mouse-down that began while inactive as activation-only, so text selection/drag can require a second drag unless a future safe non-replay fix is proven.
- Launch at Login: uses the ServiceManagement main-app login item API on macOS 13 and newer.
- Diagnostics summary: copies app name, version/build, bundle identifier, permission, startup, click detection, feature state, event tap requested/installed state, event tap mask, safety note, and concise known limitations.
- Diagnostics menu polish: visible runtime details stay out of the menu; `Copy Diagnostics Summary`, `Open Accessibility Settings`, and `Quit` use left-slot action icons with two-space title padding, and Quit preserves Cmd+Q.
- Accessibility onboarding: available from `Permissions & Startup` > `Open Accessibility Settings`.

## Experimental Or Placeholder Items

`Hover Click Assist` is an experimental placeholder. It defaults off, is disabled while Left Click Focus is off, and currently performs no delayed verification, synthetic click, cursor movement, replacement event, or mouse-move focus behavior.

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
- `NULL` is returned only for system tap-disabled pseudo-events or a null incoming event.

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

- Launch `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh` only when a manual UI test is intended.
- Confirm the app appears as a menu bar status item.
- Confirm the status menu shows `HoverClick` and `v0.4.4` on the same header row.
- Confirm `Left Click Focus` is checked by default.
- Confirm `Right Click Focus` is unchecked by default.
- Confirm `Permissions & Startup` contains Accessibility status, Launch at Login, and Open Accessibility Settings.
- Confirm `Hover` contains `Hover Click Assist`.
- Confirm `Diagnostics` contains `Version 0.4.4 (30)`, `Verbose Diagnostics`, and `Copy Diagnostics Summary`.
- Confirm `Copy Diagnostics Summary` uses a copy-style action symbol and does not show a checkmark.
- Confirm `Open Accessibility Settings` uses its action symbol and two-space title padding.
- Confirm `Quit` uses one left-slot action symbol, two-space title padding, and preserves Cmd+Q.
- Move the pointer over background windows without clicking; no focus change should occur.
- With `Left Click Focus` checked, click visible background windows; target focus should occur before the original click passes through.
- With `Right Click Focus` checked, right-click visible background windows; target focus should occur before the original right-click passes through and the normal context menu works.
- Click HoverClick status/menu UI and transient menu/popover UI; they should be ignored safely.
- Drag windows, select text, and use sliders; drag behavior should remain unchanged.
- Copy diagnostics and confirm it includes app name, version/build, bundle identifier, permission, startup, feature states, event tap requested/installed state, event tap mask, the safety note, and concise known limitations.
