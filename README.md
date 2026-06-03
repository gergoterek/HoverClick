# HoverClick

HoverClick makes click-to-focus on macOS faster and more predictable.

Phase 2 implements real click-to-focus diagnostics and behavior. Phase 1 only proved that the app could observe left mouse down events; `observed leftMouseDown` is event detection only, not proof that focus changed.

When the event tap sees a left mouse down, HoverClick resolves the Accessibility element under the cursor, finds the owning process and window, attempts `AXRaise`, activates the owning app, tries supported focused-window attributes, verifies the front app after the action, and then passes the original click through unchanged.

This version does not synthesize mouse events, move or resize windows, move the cursor, add hover assist, or create a DMG.

Manual Phase 2 logs have confirmed click-to-focus for background Finder, Chrome, and iTerm windows. HoverClick status/menu clicks are ignored safely, and useful logs distinguish click receipt, target resolution, action attempts, verification, and pass-through.

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
/usr/bin/log stream --style compact --predicate 'process == "HoverClick" AND eventMessage CONTAINS[c] "HoverClick:"'
```
