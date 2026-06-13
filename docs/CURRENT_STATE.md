# Current State

## Identity

- Project name: `HoverClick`
- Project path: `/Users/gergoterek/Movies/OBS/GPT/HoverClick`
- App name: `HoverClick`
- Bundle identifier: `com.gergoterek.HoverClick`
- Signing identity: `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`
- Visible menu header: `HoverClick` with dynamic `v0.5.0` on the same row
- Full version/build UI surface: `About HoverClick...`
- Bundle short version/build version: `0.5.0` / `34`
- Latest public release: `v0.5.0` / build `34`
- Main/release commit: `v0.5.0` tag target
- Public DMG: `HoverClick-0.5.0.dmg`
- Public DMG SHA-256: `0eaa8b68ff38a7c688271bbd83537ee8d62a26d924f47538882cbbe8dc48424e`
- App icon source asset: `assets/HoverClickAppIcon-1024.png`
- Generated bundle icon: `Resources/HoverClick.icns`

## Commands

- Build: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh`
- Verify: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh`
- Internal/test Apple Development signed DMG package: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh`
- Manual run: `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh`

`scripts/run-app.sh` is the approved signed `.app` runtime refresh step after build and verify pass for UI, resource, icon, or version metadata changes. It launches the signed `.app` bundle with `/usr/bin/open` and is not a release packaging step.

## Current Distribution

- HoverClick is distributed from GitHub. The latest public release is v0.5.0 / build 34.
- The public release DMG is `HoverClick-0.5.0.dmg`; its SHA-256 is `0eaa8b68ff38a7c688271bbd83537ee8d62a26d924f47538882cbbe8dc48424e`.
- Building locally from source remains supported.
- The local `scripts/package-dmg.sh` workflow is still an internal/test Apple Development signed packaging path and is not notarized, not Developer ID signed, and not a polished public installer path by itself.
- There is no Mac App Store release or signed `.pkg` installer.

## Current Product Behavior

- HoverClick is a menubar-only accessory app with no Dock icon.
- The menu bar icon uses the native template SF Symbol `cursorarrow.click`.
- The app bundle icon is generated from the branded source image at `assets/HoverClickAppIcon-1024.png` into `Resources/HoverClick.icns`.
- The menu header shows `HoverClick` and the visible app version.
- `Left Click Focus` defaults on.
- `Right Click Focus` defaults off and is independent from left-click behavior.
- `Hover` contains `Hover Click Assist`.
- `Permissions & Startup` contains Accessibility status, Launch at Login, and `Open Accessibility Settings`.
- `Accessibility: Granted` shows a native menu checkmark when Accessibility permission is granted; `Accessibility: Not Granted` is unchecked.
- `Diagnostics` contains `Verbose Diagnostics` and `Copy Diagnostics Summary`.
- The top-level menu contains `About HoverClick...`, which shows a small native version/build/bundle ID alert and opens no browser, System Settings, or external links.
- Technical click detection and last action details are available in the copied diagnostics summary.

## Stable Features

- Left-click focus: a left click on a background window can focus the target before the original click is delivered.
- Right-click focus: when enabled, a right click on a background window can focus the target before the original right-click continues.
- Finder context-menu follow-up left-click v2: after a recent Finder right-click that leaves Finder frontmost, the next left-click passes through before AX hit-testing so the context menu can dismiss and Finder can handle the click more natively.
- Overlay/menu-bar pass-through: HoverClick records the topmost CoreGraphics window under each focus-triggering click, then uses AX hit-testing to distinguish protected menu/status/system UI from normal app-window candidates. Menu bar, status-item, compact popup-style overlay, and popover UI still receive the original click unchanged.
- Bartender/menu-bar overlay pass-through: expanded or overflow menu bar items remain protected by the menu-bar/system UI owner and compact-overlay checks.
- Background text first-drag limitation: HoverClick still returns the original mouse-down unchanged, but some apps may treat the first mouse-down that began while inactive as activation-only, so text selection/drag can require a second drag unless a future safe non-replay fix is proven.
- Launch at Login: uses the ServiceManagement main-app login item API on macOS 13 and newer.
- Diagnostics summary: copies app name, bundle identifier, permission, startup, click detection, feature state, Hover Click Assist setting and no-op runtime behavior, event tap requested/object/source/validity/installed/enabled state, last event tap callback, last left/right mouse-down timestamps, last recovery attempt/result, last handled action, last focus action/skip reason, last non-menu focus action/skip, overlay/system UI skip reason, overlay candidate owner/window/layer/title/bounds plus AX role/subrole/app detail, last eligible hit-test candidate, persistent last background-focus trigger/target/frontmost-before/activation/AX-operation/immediate-frontmost/delayed-verification/result/failure details, last verified successful background focus, event tap mask, safety note, and concise known limitations. Version/build are shown by `About HoverClick...` instead of being duplicated in copied diagnostics.
- Diagnostics menu polish: visible runtime details stay out of the menu; `Copy Diagnostics Summary`, `Open Accessibility Settings`, and `Quit` use left-slot action icons with exactly 1 ASCII space of title padding, and Quit preserves Cmd+Q.
- Accessibility onboarding: available from `Permissions & Startup` > `Open Accessibility Settings`.

## v0.4.6 Validated Release

v0.4.6 / build 32 is fully released, validated, and closed. It is a focused bugfix release after v0.4.5. It includes the overlay/system UI skip ordering fix so large transparent or otherwise non-interactive non-layer-0 windows do not suppress normal eligible AX app-window candidates underneath them.

The release preserves menu/status/Bartender overlay protection while improving diagnostics for last non-menu focus action/skip, overlay/system UI skip reason, overlay/system UI candidate, and last eligible hit-test candidate. `Copy Diagnostics Summary` should preserve the useful last non-menu focus result instead of erasing it with later menu or overlay clicks.

Manual main validation passed for Chrome as the eligible normal app/window target while a large overlay/system UI candidate was skipped appropriately. Background focus succeeded with activation attempted=yes, returnValue=yes, AX operations attempted:success, delayed verification passing after 0.20s, result success, and verification delayed passed.

Post-release published DMG manual smoke validation passed for the GitHub v0.4.6 release asset `HoverClick-0.4.6.dmg`. The downloaded DMG SHA-256 matched `4e31b9196458e326bc794dbeb33525ce4a8d2b58fe463de0e9c3c789d3a6c076`; launch worked; the menu opened; version showed `0.4.6` / build `32`; Accessibility status was correct; Left Click Focus worked; Right Click Focus worked when enabled; diagnostics background-focus fields worked; Finder context-menu follow-up left-click worked; Bartender/menu-bar overlay pass-through worked; Copy Diagnostics Summary worked; and Quit/Cmd+Q worked. The user confirmed the DMG-installed app worked normally.

v0.4.7 later shipped from the validated post-v0.4.6 maintenance/UI/docs polish state.

The event tap mask remains left mouse down + right mouse down only. No synthetic clicks, event replay, cursor movement, mouse-move focus, scroll focus, `mouseDragged`/`mouseUp` handling, or `CGEventPost` were added. Hover Click Assist remains a no-op placeholder, not a real runtime feature.

## v0.4.7 Public Release

v0.4.7 / build 33 is the latest public release until v0.5.0 is explicitly released.

Included polish:

- `About HoverClick...` is the native alert that shows Version, Build, bundle ID, and the description.
- The visible top menu/header version label is dynamic `v<short-version>` from `CFBundleShortVersionString` through the version helper, not hardcoded.
- Tooltip wording stays release-independent: `HoverClick - Windows-like click focus for macOS`.
- `Copy Diagnostics Summary` does not include a separate Version line.
- The Diagnostics submenu does not include a separate version/build row.
- Documentation records the validated v0.4.6 state, the fresh Accessibility checklist, v0.4.7 guardrails, branch cleanup recommendations, and the failed background drag warning.

Not included:

- No event-tap mask change.
- No mouse-move, mouse-dragged, mouse-up, or scroll handling.
- No synthetic clicks, event replay, cursor movement, `CGEventPost`, `CGEventCreateMouseEvent`, `CGDisplayMoveCursorToPoint`, or `CGWarpMouseCursorPosition`.
- No Scroll Focus, Modifier Key Focus, real Hover Click Assist, app icon integration, app rename, bundle identifier change, signing identity change, DMG packaging, tag creation, or GitHub release creation.

## v0.5.0 Public Release

v0.5.0 / build 34 is the latest public release. It ships the safe public-polish batch after explicit release-scope confirmation.

Included:

- Imported source icon asset: `assets/HoverClickAppIcon-1024.png`
- Generated bundle icon: `Resources/HoverClick.icns`
- `Info.plist` icon reference: `CFBundleIconFile = HoverClick.icns`
- Build script bundling: `scripts/build-app.sh` copies `Resources/HoverClick.icns` into `HoverClick.app/Contents/Resources/HoverClick.icns` and re-signs the app with the same Apple Development identity after the resource copy.
- Verify script icon checks: `scripts/verify-app.sh` confirms the app bundle declares and contains `HoverClick.icns`.
- Signed `.app` runtime-refresh workflow fix for icon resources through `scripts/run-app.sh`.
- README, docs/WORKFLOW, and app icon smoke-test coverage polish.
- No runtime/event-tap behavior changes.

Regenerate the `.icns` from the source asset with built-in macOS tooling:

```sh
cd /Users/gergoterek/Movies/OBS/GPT/HoverClick
mkdir -p .icon-work/HoverClick.iconset Resources
sips -z 16 16 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_16x16.png
sips -z 32 32 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_16x16@2x.png
sips -z 32 32 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_32x32.png
sips -z 64 64 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_32x32@2x.png
sips -z 128 128 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_128x128.png
sips -z 256 256 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_128x128@2x.png
sips -z 256 256 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_256x256.png
sips -z 512 512 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_256x256@2x.png
sips -z 512 512 assets/HoverClickAppIcon-1024.png --out .icon-work/HoverClick.iconset/icon_512x512.png
cp assets/HoverClickAppIcon-1024.png .icon-work/HoverClick.iconset/icon_512x512@2x.png
iconutil -c icns .icon-work/HoverClick.iconset -o Resources/HoverClick.icns
rm -rf .icon-work
```

Release prep, DMG packaging, tag creation, and GitHub release creation for v0.5.0 were performed only after explicit release-scope confirmation.

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

Modifier Key Focus / Hold-to-Focus remains a future idea only. It is not designed or implemented in the current build.

## Finder Right-Click Actual Selection Limitation

- Finder may keep the previous actual selection while showing a separate context-target highlight for a right-clicked item.
- HoverClick does not currently force the right-clicked Finder item to become the actual selection.
- The safe Accessibility-only approach was not reliable.
- HoverClick should not use synthetic clicks, event replay, or cursor movement to force that behavior.

## Background Click-And-Drag Experiments

The failed 35 ms background drag assist / activation-settle experiment must not be reused. Future background click-and-drag work must start from a new, explicit, very risky branch and must not synthesize clicks, replay events, move the cursor, or expand the stable event tap mask without separate approval.

## Event Tap

- Current event tap mask: `CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)`.
- `kCGEventMouseMoved` and scroll events are not observed.
- Normal tap callback behavior returns the original event unchanged.
- System tap-disabled pseudo-events are not treated as normal mouse events.
- Disabled-by-timeout and disabled-by-user-input callbacks attempt to re-enable the existing tap when user intent is still enabled and the CFMachPort/run loop source are valid.
- If re-enable fails, or if the tap port/source is missing or invalid, HoverClick removes the stale objects and recreates the same left/right mouse-down-only event tap.
- The callback returns the incoming pseudo-event value for system tap-disabled pseudo-events, and returns `NULL` only when the incoming event is `NULL`.
- Copied diagnostics distinguish requested state, tap object/source presence, port/source validity, believed installed/enabled state, detected enabled state when available, the last callback type, last left/right mouse-down timestamps, last recovery attempt/result, the volatile last handled action, the last non-menu focus decision, overlay/system UI skip detail, the last eligible hit-test candidate, and persistent background-focus execution fields that include frontmost-before, activation return value, AX operation results, immediate verification, delayed verification, final result, failure reason, and success state that are not erased by later menu or overlay clicks.

## Permission And Signing Rules

- Accessibility permission belongs to the signed app bundle identity.
- Always launch as the signed `HoverClick.app` bundle, not the raw binary.
- Stable signing is required.
- Missing Accessibility should leave the app open and show `Accessibility: Not Granted`.
- No Screen Recording, Input Monitoring, or additional permission is currently required.

## Version Rule

- The visible menu version reads from `CFBundleShortVersionString`.
- The header displays the short version as `v<short-version>`.
- `About HoverClick...` displays `Version <short-version>` and `Build <build-version>`.
- The status item tooltip and Diagnostics submenu do not show version/build.
- `CFBundleVersion` is an internal build number outside the About alert.
- Documentation-only tasks should not change app version fields.
- Release-prep metadata tasks may change version/build fields only for the explicit target version/build and must not package, tag, or publish the release before review, merge, and manual smoke validation if needed.

## Branch Cleanup Notes

Branch cleanup candidates exist after v0.4.6, but deletion requires explicit user approval. Do not delete local or remote branches automatically.

Current safe cleanup candidates observed as merged into `main`: `batch-post-v0.4.6-maintenance-ui-docs`, `release-v0.4.7-prep`, `docs-post-v0.4.5-accessibility-flow-checklist`, `stabilize-overlay-hit-test-skip`, and `release-v0.4.6-prep`. Deleting them still requires explicit user approval.

`investigate-background-click-drag` is not merged into `main` and should be treated as a failed background drag experiment branch. Do not delete it automatically, do not merge it automatically, do not continue background click-and-drag work in this task, and do not reuse its failed 35 ms activation-settle approach.

Prefer larger coherent batches like this v0.5.0 public-polish batch when changes share release documentation, build verification, and public-facing context. Use smaller branches for risky runtime, signing, permission, or release creation work.

## Development Workflow

- `main` is the stable baseline.
- Development work should use task branches.
- Use `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/checkpoint.sh` to build, verify, commit intentional changes, and push the current task branch.
- Merge task branches into `main` only after review and manual approval.

## Manual Test Checklist

Manual Finder UI validation -- not run automatically.

- Confirm the published GitHub v0.4.6 DMG smoke test result is recorded: downloaded `HoverClick-0.4.6.dmg`, SHA-256 `4e31b9196458e326bc794dbeb33525ce4a8d2b58fe463de0e9c3c789d3a6c076`, launched successfully, showed version `0.4.6` / build `32`, reported correct Accessibility status, passed left-click focus, passed right-click focus when enabled, copied diagnostics, preserved Finder context-menu follow-up left-click behavior, preserved Bartender/menu-bar overlay pass-through, and quit through the menu/Cmd+Q.
- Launch `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh` only when a manual UI test is intended.
- Confirm the app appears as a menu bar status item.
- Confirm the status menu shows `HoverClick` and `v0.4.6` on the same header row.
- Confirm the status menu shows `HoverClick` and dynamic `v0.4.7` on the same header row after a manual relaunch.
- Confirm the status menu shows `HoverClick` and dynamic `v0.5.0` on the same header row after a manual relaunch.
- For v0.5.0 icon smoke validation, confirm the built `HoverClick.app` shows the branded app icon in normal macOS icon surfaces after a manual relaunch or install. Manual Finder UI validation -- not run automatically.
- Confirm `Left Click Focus` is checked by default.
- Confirm `Right Click Focus` is unchecked by default.
- Confirm `Permissions & Startup` contains Accessibility status, Launch at Login, and Open Accessibility Settings.
- Confirm `Hover` contains `Hover Click Assist`.
- Confirm `Diagnostics` contains `Verbose Diagnostics` and `Copy Diagnostics Summary`.
- Confirm `About HoverClick...` shows HoverClick, Version 0.4.6, Build 32, Bundle ID `com.gergoterek.HoverClick`, and the description `Windows-like click focus for macOS.` without opening any external UI.
- Confirm `About HoverClick...` shows HoverClick, Version 0.4.7, Build 33, Bundle ID `com.gergoterek.HoverClick`, and the description `Windows-like click focus for macOS.` without opening any external UI.
- Confirm `About HoverClick...` shows HoverClick, Version 0.5.0, Build 34, Bundle ID `com.gergoterek.HoverClick`, and the description `Windows-like click focus for macOS.` without opening any external UI.
- Confirm `Copy Diagnostics Summary` uses a copy-style action symbol and does not show a checkmark.
- Confirm `Open Accessibility Settings` uses its action symbol and exactly 1 ASCII space of title padding.
- Confirm `Quit` uses one left-slot action symbol, exactly 1 ASCII space of title padding, and preserves Cmd+Q.
- Confirm `Copy Diagnostics Summary` includes the event tap lifecycle fields: requested, object exists, port valid, run loop source exists, run loop source valid, installed/enabled believed state, detected enabled state, last callback, last left/right mouse-down, last recovery attempt/result, last focus action/skip, last background-focus trigger/target/frontmost-before/activation/AX/immediate/delayed/final verification/failure reason, and last verified successful background focus.
- Move the pointer over background windows without clicking; no focus change should occur.
- With `Left Click Focus` checked, click visible background windows; target focus should occur before the original click passes through.
- With `Right Click Focus` checked, right-click visible background windows; target focus should occur before the original right-click passes through and the normal context menu works.
- Click HoverClick status/menu UI and transient menu/popover UI; they should be ignored safely.
- Drag windows, select text, and use sliders; drag behavior should remain unchanged.
- Copy diagnostics and confirm it includes app name, bundle identifier, permission, startup, feature states, expanded event tap lifecycle state, event tap mask, the safety note, and concise known limitations. Confirm version/build are available from `About HoverClick...` instead.
- Leave the app running for a longer period, including idle/sleep/wake or lock-unlock if practical. If left and right click focus stop together, copy diagnostics immediately and compare the requested/enabled/validity/recovery fields.
