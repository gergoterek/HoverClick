# Sparkle Appcast Release Workflow

This document defines the safe future workflow for publishing HoverClick's Sparkle appcast at:

```text
https://gergoterek.github.io/HoverClick/appcast.xml
```

This branch does not create a v0.8.0 release. It does not create a tag, GitHub Release, DMG, appcast entry, upload, version/build bump, signing change, or runtime change.

## Hosting Strategy

Recommended strategy: publish `appcast.xml` from a dedicated `gh-pages` branch at the repository root.

Reasons:

- The app already points `SUFeedURL` at the GitHub Pages project URL.
- A `gh-pages` branch keeps appcast publishing separate from app source, generated build products, ignored `dist/` output, and release-prep commits on `main`.
- The feed URL can remain stable while DMG payloads live as immutable GitHub Release assets.
- Publishing the feed can be reviewed as a small static-file change without mixing it into app-code history.

Other options considered:

- GitHub Pages from `main` branch root: not recommended because it would place public web feed files beside app source and make source merges implicitly affect the web root.
- GitHub Pages from `docs/`: possible, but not recommended because project documentation and the public updater feed have different lifecycles.
- Manual static HTTPS hosting: safe if configured carefully, but it adds infrastructure outside the repository.

Unresolved assumption: the repository does not contain tracked GitHub Pages settings, so this branch cannot prove whether Pages is currently configured for `gh-pages`, `main`, or `docs/`. Do not commit a real `appcast.xml` location until the GitHub Pages source is confirmed in the repository settings.

## Current v0.8.0 State

Current `main` contains unreleased v0.8.0 work:

- Sparkle Phase 1 manual update MVP.
- `Check for Updates...` menu item.
- Sparkle 2.9.3 framework integration.
- `SUFeedURL = https://gergoterek.github.io/HoverClick/appcast.xml`.
- `SUPublicEDKey = 093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o=`.
- Automatic Sparkle checks disabled.
- Background automatic download/install disabled.
- First-launch Accessibility onboarding and permission refresh polish.
- Launch at Login consent-only onboarding.

Not done yet:

- No v0.8.0 tag.
- No v0.8.0 DMG.
- No v0.8.0 GitHub Release.
- No version/build bump for v0.8.0.
- No published appcast.

## Preflight Tool

Use the non-publishing helper only after a real future release DMG and public GitHub Release asset URL exist:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/prepare-appcast.sh \
  --release-dmg /path/to/HoverClick-0.8.0.dmg \
  --download-url https://github.com/gergoterek/HoverClick/releases/download/v0.8.0/HoverClick-0.8.0.dmg \
  --version 0.8.0 \
  --build 37 \
  --output /path/to/gh-pages-checkout/appcast.xml
```

By default this is a dry run. It validates required release data, the DMG filename/URL match, size, SHA-256, and the pinned Sparkle 2.9.3 `generate_appcast` tool path. It does not write an appcast unless `--write` is passed.

To generate a local appcast file after the real release DMG exists:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/prepare-appcast.sh \
  --release-dmg /path/to/HoverClick-0.8.0.dmg \
  --download-url https://github.com/gergoterek/HoverClick/releases/download/v0.8.0/HoverClick-0.8.0.dmg \
  --version 0.8.0 \
  --build 37 \
  --output /path/to/gh-pages-checkout/appcast.xml \
  --write
```

The script:

- uses the pinned Sparkle 2.9.3 cache under `tmp/sparkle/`;
- uses the Sparkle Keychain account `com.gergoterek.HoverClick` by default;
- does not accept or store private key material;
- writes only to an explicit local output path when `--write` is passed;
- does not upload, publish, create a tag, create a release, or package a DMG.

## Future Release Workflow

Only perform these steps in an explicit release task:

1. Confirm GitHub Pages source for `https://gergoterek.github.io/HoverClick/appcast.xml`.
2. Bump version/build for the intended release on a release-prep branch.
3. Build and verify the signed app.
4. Package the final public DMG through the approved release packaging path.
5. Compute and record the DMG SHA-256.
6. Create and push the release tag.
7. Create the GitHub Release.
8. Upload exactly one DMG asset with the expected filename.
9. Run `scripts/prepare-appcast.sh` with the final DMG path and final public DMG asset URL.
10. Review the generated `appcast.xml` for the expected version, build, URL, length, and `sparkle:edSignature`.
11. Publish `appcast.xml` to the confirmed GitHub Pages/static location.
12. Verify `https://gergoterek.github.io/HoverClick/appcast.xml` is reachable over HTTPS.
13. Verify the appcast points to the uploaded DMG and that the DMG URL is reachable.
14. From an older updater-enabled HoverClick build, use `Check for Updates...` against the live appcast.

## Stop Gates

Stop the release workflow if any of these are true:

- The Sparkle Keychain signing key for `com.gergoterek.HoverClick` is unavailable.
- GitHub Pages hosting source is unknown.
- The live appcast URL is not reachable after publish.
- The appcast points to a missing or wrong DMG.
- The appcast signature does not match the uploaded DMG.
- The GitHub Release has duplicate, missing, or wrong assets.
- The release version/build does not match `Info.plist` and the appcast item.
- The DMG filename or URL does not match the intended release.
- The release artifact was produced by the wrong packaging path.
- The signing identity, bundle identifier, or app name changed unexpectedly.
- Sparkle automatic checks or background install settings changed unexpectedly.
- Private keys, signing secrets, generated Sparkle secret files, or credentials appear in the repository.

## Non-Goals

This workflow does not add Developer ID signing, notarization, automatic update checks, background download/install, release uploads, package changes, event-tap changes, Accessibility/TCC changes, or app runtime changes.
