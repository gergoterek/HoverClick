# HoverClick

HoverClick makes click-to-focus on macOS faster and more predictable.

Phase 3 keeps the stable Phase 2 click-to-focus behavior and removes the earlier AutoRaise-style Hover Focus experiment. Phase 1 only proved that the app could observe left mouse down events; `observed leftMouseDown` is event detection only, not proof that focus changed.

When the event tap sees a left mouse down, HoverClick resolves the Accessibility element under the cursor, finds the owning process and window, attempts `AXRaise`, activates the owning app, tries supported focused-window attributes, verifies the front app after the action, and then passes the original click through unchanged. `Right Click Focus` uses the same safe focus path when enabled, then returns the original right-click event unchanged so the normal context menu can still appear.

HoverClick is not an AutoRaise-style hover-focus app. It does not focus windows merely because the pointer moves over them, and the event tap does not observe mouse-moved events. Normal macOS interaction is preserved: HoverClick attempts focus before click delivery, then returns the original click event unchanged.

The menu shows `HoverClick` and the visible `v0.4.2 (21)` build label on one header row so the running build can be identified quickly. It reads the app version/build from `CFBundleShortVersionString` and `CFBundleVersion`; intentional shipped behavior or UI changes should bump those fields, while build/verify-only, git checkpoint, read-only audit, or documentation-only tasks may keep them unchanged.

The menu separates stable `Left Click Focus`, which defaults ON, from independent `Right Click Focus`, which defaults OFF. The `Hover` submenu contains `Hover Click Assist`, which defaults OFF and is disabled whenever Left Click Focus is off. The stored Hover Click Assist preference is preserved while the submenu is disabled and restored when Left Click Focus is turned back on. Hover Click Assist is currently a no-op experimental feature flag only; it does not schedule delayed verification, synthesize clicks, move the cursor, post replacement events, or focus windows from mouse movement.

The `Permissions & Startup` submenu groups Accessibility status and Launch at Login, with `Open Accessibility Settings` at the bottom as an explicit user-click action. `Launch at Login` uses the modern ServiceManagement main-app login item API on macOS 13 and newer. The item is independent from Accessibility permission, Left Click Focus, Right Click Focus, and Hover Click Assist.

The `Diagnostics` submenu keeps technical details out of the normal menu. It includes `Verbose Diagnostics` and `Copy Diagnostics Summary`, which copies version, permission, startup, click detection, last handled action, feature state, event tap mask, and stable-core safety details.

This version does not synthesize mouse events, move or resize windows, move the cursor, or create a DMG.

Manual checkpoint validation has confirmed Left Click Focus, Right Click Focus, Launch at Login, unchanged context-menu behavior, stable Accessibility permission, and no focus from mouse movement alone. HoverClick status/menu clicks are ignored safely, and useful logs distinguish click receipt, target resolution, action attempts, verification, and pass-through.

The current stability-hardened checkpoint adds click sequence ids to diagnostics, duplicate event-tap install guards, clearer event-tap disabled/re-enabled logs, bounded AX parent climbing, and immediate verification. Delayed verification has been removed from runtime so the stable path stays immediate.

## Build And Run

Build and launch the app bundle:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh
```

Build without launching:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
```

Verify the built app:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

Always run HoverClick as `HoverClick.app`. Never run the raw binary at `HoverClick.app/Contents/MacOS/HoverClick` directly, because Accessibility permission must attach to the signed app bundle identity.

Watch behavior in the unified log:

```sh
/usr/bin/log stream --style compact --predicate 'process == "HoverClick" AND eventMessage CONTAINS[c] "[HoverClick]"'
```
