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

## Release Scope

Release prep, DMG packaging, tags, and GitHub releases require explicit release-scope confirmation. `scripts/run-app.sh` is for local runtime refresh after build and verify, not for packaging or publishing.
