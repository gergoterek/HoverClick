# Workflow

## Build And Verify

Use the signed app build script for local validation:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

`scripts/build-app.sh` creates `HoverClick.app`, copies bundled resources such as `Resources/HoverClick.icns` into `HoverClick.app/Contents/Resources/`, and signs the app with the configured Apple Development identity.

`scripts/verify-app.sh` checks the bundle identifier, icon declaration, bundled icon resource, signing identity, code signature verification, and process count.

## Runtime Refresh

After build and verify pass for code, runtime, diagnostics, UI, app-resource, icon, or version-build metadata changes, use:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh
```

This is the approved signed `.app` runtime refresh step. It relaunches `HoverClick.app` through the normal signed app bundle path and must not be treated as release packaging.

Do not run the raw executable inside `HoverClick.app/Contents/MacOS/` for normal validation because Accessibility permission belongs to the signed app bundle identity.

## Runtime Behavior Validation

Runtime behavior changes require manual validation after the signed `.app` has been rebuilt and verified. Automated checks can prove syntax, signing, bundle identity, event tap mask, and static safety guardrails, but they do not prove right-click focus, context menu, double-click, or drag/selection behavior.

Manual Finder UI validation -- not run automatically.

For the v0.7.0 Right Click Focus stability batch, manually cover:

- Left Click Focus still focuses a background window and returns the original left-click unchanged.
- With `Right Click Focus` unchecked, right-clicking a background window does not run a HoverClick focus attempt; copied diagnostics show right mouse down observation and a disabled-setting skip.
- With `Right Click Focus` checked, right-clicking a background Finder window from Chrome focuses/raises Finder without intentionally breaking the context menu; copied diagnostics show target app/window detection, focus attempt, AX operation result, immediate verification, delayed verification if needed, and last verified successful background focus if successful.
- Context menu, double-click, background drag/selection, menu bar/system UI skip, and diagnostics-summary copy behavior remain unchanged except for the clearer diagnostic text.

For the long-run click-focus investigation batch, manually cover:

- Immediate left-click background focus.
- Immediate right-click background focus with `Right Click Focus` enabled.
- Menu/status UI skip behavior.
- `Copy Diagnostics Summary` after a menu/status click; volatile fields may show the menu interaction, but stable last real/background click fields and recent non-menu decision history should still show the meaningful click path.
- Normal background clicks that previously showed a tiny untitled `Window Server` compact popup/menu skip should now show the Window Server surface ignored as pass-through, AX target accepted, and focus attempt started.
- Repeated background focus attempts across Finder, Chrome, and a terminal/editor app if practical.
- Extended idle, sleep/wake, or lock-unlock reproduction. If focus stops while mouse-down callbacks still update, copy diagnostics immediately.
- In the failure snapshot, preserve the recent non-menu mouse-down decision history, aggregate counters, stable last real/background click fields, event tap lifecycle state, last left/right mouse-down timestamps, and background-focus AX/immediate/delayed verification fields.

## DMG Packaging

Use the internal/test DMG package script only after build and verify are expected to pass:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh
```

`scripts/package-dmg.sh` rebuilds and verifies `HoverClick.app`, stages the signed app, adds an `Applications` symlink, copies the dedicated DMG volume icon resource `Resources/HoverClickDMGVolumeIcon.icns` as `.VolumeIcon.icns`, sets the custom volume icon flag with command-line tooling, compresses the final DMG, then mounts the final image with `hdiutil -nobrowse -noautoopen` for verification.

The package verification checks that the mounted DMG contains the expected `HoverClick.app`, bundle identifier, version, build, valid code signature, `Applications` symlink target, `.VolumeIcon.icns` matching `Resources/HoverClickDMGVolumeIcon.icns`, hidden icon file flag, and custom volume icon flag. It does not open Finder, System Settings, browsers, or the app runtime.

The reliable release packaging polish is the mounted DMG volume icon. The `.dmg` file's own Finder icon before mounting is intentionally not customized because that kind of file icon depends on local Finder metadata such as resource forks or extended attributes and is not treated as a reliable GitHub Release asset property after upload/download.

Manual Finder UI validation -- not run automatically.

After packaging, a manual smoke test may inspect the mounted DMG presentation in Finder, confirm the mounted volume uses the dedicated branded volume icon, drag `HoverClick.app` to the `Applications` shortcut, launch the installed signed app bundle, confirm `About HoverClick...` shows the expected version/build, confirm Accessibility status, and exercise left/right click focus according to the release checklist. Users with Finder hidden files shown may also see `.VolumeIcon.icns`; that is expected as long as command-line verification reports the hidden flag is set.

Finder window background and icon layout remain future optional polish. They should be added only if a deterministic non-GUI approach is proven safe; packaging automation must not rely on Finder UI scripting or manual Finder layout.

## Release Scope

Release prep, DMG packaging, tags, and GitHub releases require explicit release-scope confirmation. `scripts/run-app.sh` is for local runtime refresh after build and verify, not for packaging or publishing.
