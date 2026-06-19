# HoverClick v0.8.0 Updater Design

## Purpose

This is the design proposal for adding automatic update support after the validated `v0.7.0` / build `36` release.

This document does not implement Sparkle, add dependencies, change app code, change `Info.plist`, change signing, create release artifacts, tag a release, or publish a GitHub Release.

## Recommended Architecture

Use Sparkle 2 as the updater framework.

Sparkle is the safer default than a custom GitHub downloader because it already provides the updater-specific machinery HoverClick would otherwise need to implement and validate from scratch:

- version comparison through `CFBundleVersion`;
- RSS appcast parsing;
- archive download and validation;
- EdDSA update signatures;
- Apple code-signing validation;
- quarantine, permissions, authentication, and replacement behavior;
- atomic update installation behavior;
- standard user-facing update UI;
- appcast generation and optional delta update support through `generate_appcast`.

The update source should be a static HTTPS Sparkle appcast. The appcast is the authority that tells HoverClick whether an official update exists. GitHub Releases should host the official DMG artifacts, and each appcast item should point at one official GitHub Release asset, for example:

```text
https://github.com/gergoterek/HoverClick/releases/download/v0.8.0/HoverClick-0.8.0.dmg
```

Normal git pushes must not trigger app updates. A push only changes source code. An app update should exist only after a release artifact has been built, signed, packaged, signed for Sparkle, added to the appcast, and published as part of an intentional GitHub Release workflow.

The recommended public appcast URL is a stable GitHub Pages URL such as:

```text
https://gergoterek.github.io/HoverClick/appcast.xml
```

`Info.plist` would later need `SUFeedURL` set to that stable appcast URL and `SUPublicEDKey` set to the Sparkle EdDSA public key. It should not be changed in this design-only task.

Official Sparkle references used for this proposal:

- Sparkle setup and appcast publishing: https://sparkle-project.org/documentation/
- Sparkle update signing: https://sparkle-project.org/documentation/publishing/
- Sparkle automatic-check settings: https://sparkle-project.org/documentation/customization/
- Sparkle programmatic Cocoa setup: https://sparkle-project.org/documentation/programmatic-setup/
- Sparkle security and reliability notes: https://sparkle-project.org/documentation/security-and-reliability/

## Product Behavior

The first updater-capable release should be conservative.

Recommended MVP behavior:

- Add a `Check for Updates...` menu item.
- Use Sparkle's standard update UI.
- Let the user initiate update checks manually.
- Show standard states such as no update available, update available, download progress, install/relaunch prompts, and failure messages.
- Keep release notes visible if the appcast provides them.
- Keep the existing menu compact; the update item should be an action, not a persistent diagnostic row.

Automatic checks should not be enabled immediately. Set `SUEnableAutomaticChecks` to `NO` for the first updater release so HoverClick does not prompt for or perform background checks before the manual path is proven. After manual update checks have been validated across real releases, a later phase can enable or offer periodic checks.

Background download and automatic install should not be enabled in the first updater-capable release. Keep `SUAutomaticallyUpdate` off for the MVP. Silent or mostly silent installs should wait until the manual path, appcast publishing, update signing, release notes, replacement behavior, and Accessibility stability are proven.

What remains manual in the first version:

- publishing the GitHub Release;
- publishing or updating the appcast;
- confirming the release DMG checksum;
- manual `Check for Updates...` by the user;
- manual acceptance of the update/install prompt;
- manual validation that Accessibility permission remains stable after the update.

Important first-release expectation: `v0.7.0` does not contain an updater, so it cannot discover `v0.8.0` inside the app. The first updater-capable build must still be installed manually. Sparkle can then update that installed `v0.8.0` build to later versions such as `v0.8.1` or `v0.9.0`.

## Security And Signing Model

HoverClick's current app identity is:

- App name: `HoverClick`
- Bundle identifier: `com.gergoterek.HoverClick`
- Current local signing identity: `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`

The update path must preserve app name, bundle identifier, and signing continuity unless a separate release-signing task explicitly approves a change. Accessibility permission belongs to the signed app bundle identity, so the updater plan must avoid casual changes that could cause macOS to treat the updated app as a different app.

Sparkle's EdDSA update signatures should be mandatory for updater releases. The public key lives in the app bundle as `SUPublicEDKey` in `Info.plist`. The private key should not live in the repository, app bundle, appcast, release notes, GitHub Release assets, source files, docs, or logs. Prefer storing it in the release machine's Keychain as Sparkle's tooling expects, with any export handled as a separate secret-management decision.

Raw GitHub asset download without Sparkle signature verification is not acceptable. TLS and a release-page checksum are useful distribution signals, but they are not enough for an in-app updater that can replace a local app. The updater must verify that the downloaded archive is an intended HoverClick update before installing it.

Apple code signing remains part of the trust model. Sparkle can check both its own update signatures and Apple code signing. The safest public release path is still a Developer ID signed and notarized release artifact, but this project currently documents that public Developer ID/notarization work as deferred. If v0.8.0 implementation discovers that Developer ID/notarization is required for reliable public Sparkle updates, stop before implementation and split that into a separate signing/release task.

Accessibility stability rules:

- Do not change the app name.
- Do not change the bundle identifier.
- Do not change signing identity as a side effect of updater work.
- Do not launch the raw binary inside `Contents/MacOS`.
- Launch and validate only as the signed `.app` bundle.
- Do not use `tccutil reset` as a normal update test or troubleshooting step.
- Do not use `sudo` for update or Accessibility validation.

## Release Workflow Impact

The current `v0.7.0` release workflow publishes a GitHub Release and a public DMG. For Sparkle, the release workflow needs one additional signed appcast layer:

1. Build the signed `HoverClick.app`.
2. Package a release DMG.
3. Verify bundle identifier, version, build, and code signature.
4. Generate or update the Sparkle appcast with `generate_appcast`.
5. Confirm the appcast item points to the official GitHub Release DMG asset.
6. Confirm the appcast item includes the EdDSA signature and length for that exact artifact.
7. Publish the appcast to the stable HTTPS appcast URL.
8. Publish or finalize the GitHub Release only after the artifact and appcast are consistent.

`scripts/package-dmg.sh` should remain the internal/test Apple Development signed DMG packaging script. It should not silently become the public updater release workflow. A later implementation can either:

- add a new script such as `scripts/generate-appcast.sh` that consumes an already-built official release DMG and runs Sparkle tooling; or
- add a separate release/update packaging script if Developer ID signing and notarization are resumed.

The cleaner long-term shape is a separate updater-release script because appcast signing, Sparkle private-key access, release asset URLs, and optional Developer ID/notarization concerns are different from the existing internal/test DMG workflow.

### Appcast Hosting Options

Recommended: GitHub Pages.

Pros:

- stable HTTPS URL;
- easy static hosting for `appcast.xml` and release notes;
- works with Sparkle's appcast model;
- can keep DMG payloads on GitHub Releases while the feed lives at one stable URL;
- can be updated by a deliberate release workflow.

Cons:

- requires enabling and maintaining Pages;
- cache behavior needs to be understood during release testing;
- feed publication becomes one more release step.

Possible but not recommended as the primary feed: GitHub Release asset.

Pros:

- keeps all release files under GitHub Releases;
- no separate hosting product.

Cons:

- Sparkle needs a stable feed URL, while release assets are naturally versioned per tag;
- updating a "latest" appcast asset can be awkward and easier to break;
- content type, redirects, and caching are less clear than a purpose-built static feed URL;
- a release asset feed can blur the separation between official update metadata and versioned payloads.

Possible later: another static HTTPS URL.

Pros:

- most control over caching, redirects, content type, access logs, and custom domain;
- clean separation between feed and release payloads.

Cons:

- adds infrastructure outside the repository;
- adds another account/credential/recovery surface;
- more operational work for a small utility.

## Implementation Phases

Phase 0: design only.

- Create this design document.
- Do not add Sparkle.
- Do not change code, scripts, `Info.plist`, signing, resources, tags, release assets, or DMGs.

Phase 1: manual updater integration.

- Add Sparkle 2 framework integration.
- Add `Check for Updates...` to the HoverClick menu.
- Wire the menu item to `SPUStandardUpdaterController`.
- Add `SUFeedURL` and `SUPublicEDKey`.
- Keep automatic checks and automatic background install off.
- Verify the app still builds, signs, launches as a signed `.app`, and preserves the current click-focus/event-tap behavior.

Phase 1 implementation note:

- Sparkle is integrated from the official GitHub release `Sparkle-2.9.3.tar.xz`.
- The pinned source URL is `https://github.com/sparkle-project/Sparkle/releases/download/2.9.3/Sparkle-2.9.3.tar.xz`.
- The pinned archive SHA-256 is `74a07da821f92b79310009954c0e15f350173374a3abe39095b4fc5096916be6`.
- `Makefile` downloads that archive into the ignored `tmp/sparkle/` cache, verifies the SHA-256, extracts `Sparkle.framework`, links with `-framework Sparkle`, embeds the framework in `HoverClick.app/Contents/Frameworks/`, and signs Sparkle's nested XPC services, updater app, helper executable, framework, and app with the existing Apple Development identity.
- `SPUStandardUpdaterController` is kept alive by `HoverClickAppDelegate`, and the top-level `Check for Updates...` menu item targets `checkForUpdates:`.
- `SUFeedURL` is `https://gergoterek.github.io/HoverClick/appcast.xml`. This is the stable GitHub Pages appcast URL for the release feed.
- `SUPublicEDKey` is `093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o=`.
- The Sparkle EdDSA private key was generated with Sparkle's official `generate_keys --account com.gergoterek.HoverClick` tool and saved in the user's login Keychain. No private key file is stored in the repository.
- `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, and `SUAllowsAutomaticUpdates` are all set to false for the manual-only MVP.
- The Phase 1 implementation branch did not add appcasts, release assets, tags, GitHub Releases, DMGs, Developer ID/notarization changes, Accessibility/TCC changes, event-tap changes, or package workflow changes.

Phase 2: appcast and signed update workflow.

- Reuse the existing Sparkle EdDSA key stored in the user's Keychain under account `com.gergoterek.HoverClick`.
- Keep the private key outside the repository.
- Produce the official update DMG.
- Generate the appcast with `generate_appcast --account com.gergoterek.HoverClick` or equivalent Sparkle tooling.
- Publish the appcast to the chosen stable HTTPS URL.
- Publish the DMG as an official GitHub Release asset.
- Validate manual update from an older updater-enabled build to a newer build.

Phase 2 release publishing lives in `docs/APPCAST_RELEASE_WORKFLOW.md`. The hosting strategy is a dedicated `gh-pages` branch serving `appcast.xml` at the repository root, while DMG payloads remain immutable GitHub Release assets. `scripts/prepare-appcast.sh` is a non-publishing preflight/generation helper for a release; it requires a real DMG, final public DMG URL, version, build, and explicit output path, and it defaults to dry-run mode.

Phase 3: automatic periodic checks.

- Enable or offer periodic checks only after manual checks work across real release artifacts.
- Keep the user-visible prompt behavior understandable.
- Keep automatic download/install off.

Phase 4: optional background download/install.

- Consider `SUAutomaticallyUpdate` only after manual checks and periodic checks are stable.
- Re-test update replacement, Accessibility permission stability, install location behavior, and failure recovery.
- Keep this out of the first v0.8.0 updater MVP.

## v0.9.0 Updater Completion Recommendation

v0.8.0 completed the manual updater MVP and appcast publication path. v0.9.0 should complete the updater enough for v1.0 without making the update system aggressive.

Implemented v0.9.0 behavior:

- Keep the top-level `Check for Updates...` manual action.
- Keep `SUFeedURL` pointed at `https://gergoterek.github.io/HoverClick/appcast.xml`.
- Keep `SUPublicEDKey` unchanged.
- Keep GitHub Release DMG assets as immutable update payloads.
- Keep the appcast published from the dedicated `gh-pages` branch root.
- Keep background automatic download/install disabled with `SUAutomaticallyUpdate = false` and `SUAllowsAutomaticUpdates = false`.
- Do not set `SUEnableAutomaticChecks = true` as an unconditional default.
- Add an explicit `Automatically Check for Updates` menu toggle, default off through `SUEnableAutomaticChecks = false`, wired to Sparkle's `automaticallyChecksForUpdates` setting.
- Do not rely on a surprise second-launch automatic-check permission prompt for v0.9.0. Sparkle supports that behavior when `SUEnableAutomaticChecks` is omitted, but HoverClick keeps the key set to false and uses the explicit menu toggle instead.
- Treat automatic checks as notification-only. Updates still require Sparkle's standard user-visible update/install flow.

Complete updater for v1.0 means the user has a clear manual check path, an optional user-consented automatic check path through `Automatically Check for Updates`, a repeatable appcast workflow, and no silent background install behavior.

Hover Click Assist is not part of the v0.9.0 updater-completion scope. The visible no-op placeholder is removed instead of becoming a real feature, and no Click-Time Hover Assist, mouse-move handling, synthetic click, event replay, cursor movement, or delayed assist path is added.

## v1.0 Readiness Notes

v1.0 readiness polish should confirm the updater design rather than expand it.

- Keep `SUFeedURL` unchanged: `https://gergoterek.github.io/HoverClick/appcast.xml`.
- Keep Sparkle public key unchanged: `093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o=`.
- Keep automatic checks default off through `SUEnableAutomaticChecks = false`.
- Keep manual `Check for Updates...` available.
- Keep automatic download/install disabled through `SUAutomaticallyUpdate = false` and `SUAllowsAutomaticUpdates = false`.
- Keep `Automatically Check for Updates` as a user-controlled automatic-check toggle only.
- Treat appcast publish/update as release workflow only, not v1.0 readiness polish.
- Do not bump version/build, create a tag, create a GitHub Release, run `scripts/package-dmg.sh`, publish Pages output, change signing, or touch private Sparkle key material during readiness polish.

## Files Likely To Change Later

Future implementation will likely touch:

- `HoverClick.mm` for Sparkle controller lifetime and `Check for Updates...` menu wiring.
- `Info.plist` for Sparkle keys such as `SUFeedURL`, `SUPublicEDKey`, and automatic-check settings.
- `Makefile` for Sparkle framework include/link/embed/sign steps if the project remains non-Xcode.
- `scripts/package-dmg.sh` only if it stays internal/test and needs compatibility adjustments; otherwise prefer a new updater/release script.
- a helper such as `scripts/prepare-appcast.sh` and, if needed later, a separate release packaging script.
- docs covering release, workflow, test matrix, and current state.
- possibly release workflow docs or a GitHub Pages branch/configuration.

Do not change these files in this design-only branch.

## Validation Plan

Design-only validation for this branch:

```zsh
git diff --check
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/ci-safety-check.sh
```

Implementation-phase automated validation:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
git diff --check
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/ci-safety-check.sh
```

Manual validation for the first updater implementation:

- app launches as the signed `.app` bundle;
- the raw binary is not launched;
- Accessibility permission does not unexpectedly reset;
- `Check for Updates...` works when no update is available;
- `Check for Updates...` detects a newer appcast version;
- update download verifies the EdDSA signature;
- update refuses an unsigned or invalid update;
- update installs the expected version;
- `About HoverClick...` shows the new version/build;
- left-click and right-click focus behavior still works after update;
- diagnostics remain sane;
- no Finder UI validation is run automatically.

Manual Finder UI validation -- not run automatically.

Manual validation for v1.0 readiness should additionally confirm `Check for Updates...` reaches the live appcast without a 404, `Automatically Check for Updates` persists across relaunch, copied diagnostics report automatic-check/download/install state, and no silent/background automatic install occurs.

## Risks And Stop Gates

Stop before adding the Sparkle dependency.

Stop before changing build scripts.

Stop before changing `Info.plist`.

Stop before changing release workflow.

Stop before enabling automatic background install.

Stop if Developer ID/notarization is required and the current Apple Development signing path is insufficient for the intended public updater release.

Stop if Sparkle requires packaging assumptions that conflict with the current DMG workflow.

Stop if adding Sparkle would require app name, bundle identifier, signing identity, certificate, Accessibility/TCC behavior, event tap behavior, or release artifact changes outside an explicitly approved implementation task.

Do not continue if the update test requires launching the app executable inside `Contents/MacOS`, using `sudo`, resetting TCC, or automating Finder/System Settings UI.

## Recommendation

Recommended v0.8.0 scope:

- Sparkle 2 updater MVP.
- Manual `Check for Updates...` path first.
- Static HTTPS appcast, preferably GitHub Pages.
- Official GitHub Release DMG assets as update payloads.
- Sparkle EdDSA signatures for every update archive.
- Appcast/update signing workflow documented and validated before publishing an updater-enabled release.
- No automatic background install in the first updater-capable release.

What should not go into v0.8.0:

- custom GitHub polling/downloading updater;
- treating git pushes as updates;
- silent automatic background download/install;
- Developer ID/notarization transition unless explicitly split into a separate approved release-signing task;
- package installer work;
- release artifact generation in a design-only branch;
- app name, bundle identifier, signing identity, or certificate changes;
- Accessibility/TCC behavior changes;
- event tap, mouse handling, synthetic click, event replay, cursor movement, or focus behavior changes.
