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

After build and verify pass for UI, resource, icon, or version metadata changes, use:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh
```

This is the approved signed `.app` runtime refresh step. It relaunches `HoverClick.app` through the normal signed app bundle path and must not be treated as release packaging.

Do not run the raw executable inside `HoverClick.app/Contents/MacOS/` for normal validation because Accessibility permission belongs to the signed app bundle identity.

## DMG Packaging

Use the internal/test DMG package script only after build and verify are expected to pass:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh
```

`scripts/package-dmg.sh` rebuilds and verifies `HoverClick.app`, stages the signed app, adds an `Applications` symlink, copies the dedicated DMG volume icon resource `Resources/HoverClickDMGVolumeIcon.icns` as `.VolumeIcon.icns`, sets the custom volume icon flag with command-line tooling, compresses the final DMG, then mounts the final image with `hdiutil -nobrowse -noautoopen` for verification.

The package verification checks that the mounted DMG contains the expected `HoverClick.app`, bundle identifier, version, build, valid code signature, `Applications` symlink target, `.VolumeIcon.icns` matching `Resources/HoverClickDMGVolumeIcon.icns`, hidden icon file flag, and custom volume icon flag. It does not open Finder, System Settings, browsers, or the app runtime.

Manual Finder UI validation -- not run automatically.

After packaging, a manual smoke test may inspect the mounted DMG presentation in Finder, confirm the volume uses the branded icon, drag `HoverClick.app` to the `Applications` shortcut, launch the installed signed app bundle, confirm `About HoverClick...` shows the expected version/build, confirm Accessibility status, and exercise left/right click focus according to the release checklist.

Finder window background and icon layout remain future optional polish. They should be added only if a deterministic non-GUI approach is proven safe; packaging automation must not rely on Finder UI scripting or manual Finder layout.

## Release Scope

Release prep, DMG packaging, tags, and GitHub releases require explicit release-scope confirmation. `scripts/run-app.sh` is for local runtime refresh after build and verify, not for packaging or publishing.
