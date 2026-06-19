# Workflow

## Build And Verify

Use the signed app build script for local validation:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

`scripts/build-app.sh` creates `HoverClick.app`, copies bundled resources such as `Resources/HoverClick.icns` into `HoverClick.app/Contents/Resources/`, and signs the app with the configured Apple Development identity.

For the v0.8.0 updater release, `Makefile` also downloads the official pinned Sparkle release `Sparkle-2.9.3.tar.xz` from `https://github.com/sparkle-project/Sparkle/releases/download/2.9.3/Sparkle-2.9.3.tar.xz` into the ignored `tmp/sparkle/` cache, verifies SHA-256 `74a07da821f92b79310009954c0e15f350173374a3abe39095b4fc5096916be6`, extracts `Sparkle.framework`, links it, embeds it in `HoverClick.app/Contents/Frameworks/`, and signs Sparkle's nested helpers plus the app with the existing Apple Development identity.

`scripts/verify-app.sh` checks the bundle identifier, icon declaration, bundled icon resource, Sparkle framework embedding/version/linkage/configuration/signing, signing identity, code signature verification, and process count.

For the v0.9.0 updater-completion branch, validation should include:

```sh
git diff --check
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/ci-safety-check.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

Do not run `scripts/package-dmg.sh` for updater-completion implementation work.

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

For the Chrome / Google Docs background click-through investigation, manually cover:

- Finder frontmost to first click in a background Chrome Google Docs document body, then copy diagnostics immediately.
- Finder frontmost to second click in the same Google Docs target, then copy diagnostics again.
- Finder frontmost to first click on a Google Docs toolbar or button in background Chrome.
- Finder frontmost to first click on a normal website link or button in background Chrome.
- Finder frontmost to first click in the Chrome address bar or toolbar.
- Finder frontmost to first click on a background Chrome page that is not Google Docs.
- Repeat with Left Click Focus off if useful to compare native inactive Chrome behavior against HoverClick's focus path.
- Repeat safe right-click checks with Right Click Focus off and on if useful to confirm right-click diagnostics remain independent.
- In each snapshot, preserve `Last event tap callback`, last left/right mouse-down timestamps, source/frontmost app before click, target bundle ID, `targetIsChrome`, AX target/window fields, overlay/menu/system skip fields, focus attempt state, app activation, AX operations, immediate and delayed verification, original-event pass-through, permission fail-open fields, and `Last click-through investigation`.
- Interpret successful focus verification plus original-event pass-through plus missed Google Docs handling as likely app/web-content-level behavior, not as proof of an event tap or focus-path failure.

For the v0.8.0 first-launch permission onboarding batch, manually cover in a safe fresh-user or fresh-install scenario when available:

- Launch the signed `.app` bundle with Accessibility not yet granted.
- Confirm HoverClick requests the native Accessibility trust prompt and shows its explanatory onboarding alert without opening System Settings automatically.
- Confirm `Left Click Focus` and `Right Click Focus` are disabled while Accessibility is missing.
- Confirm `Permissions & Startup` shows `Accessibility: Required`, exposes `Check Again`, leaves `Open Accessibility Settings` as an explicit user-click action, and switches to `Accessibility: Granted` after permission is granted and refreshed.
- Confirm permission state refreshes without prompting when HoverClick becomes active and before the status menu opens.
- Confirm `Check Again` dismisses the onboarding alert after permission is granted and does not stack duplicate onboarding alerts when permission remains missing.
- Manually revoke Accessibility while HoverClick is running and confirm normal clicking still works immediately; HoverClick should record permission-missing pass-through/removal state, remove any stale tap, and avoid repeated alerts.
- After granting Accessibility again, choose `Check Again` and confirm feature controls re-enable and the event tap reinstalls without relaunch if practical.
- Confirm Launch at Login onboarding asks once when the login item is not registered, records `launchAtLoginOnboardingPromptShown`, and enables startup only when the user chooses `Enable Launch at Login`.
- Confirm copied diagnostics include Accessibility onboarding, trust prompt, permission-gated click focus, and Launch at Login onboarding fields.

Do not use `tccutil reset` for normal onboarding validation. Do not run raw binaries. Do not automate System Settings, Finder, keyboard, mouse, or Accessibility UI interactions.

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

## Sparkle Manual Update MVP

Phase 1 adds only the manual `Check for Updates...` entry point using Sparkle's standard UI.

- `SUFeedURL` is `https://gergoterek.github.io/HoverClick/appcast.xml`.
- The appcast is published through GitHub Pages at `https://gergoterek.github.io/HoverClick/appcast.xml`.
- `SUPublicEDKey` is `093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o=`.
- The private EdDSA key is in the user's login Keychain under Sparkle account `com.gergoterek.HoverClick`; do not export it into the repository.
- Automatic checks and background automatic updates stay disabled by `SUEnableAutomaticChecks = false`, `SUAutomaticallyUpdate = false`, and `SUAllowsAutomaticUpdates = false`.
- Future appcast generation should use Sparkle tooling with the same Keychain account, for example `generate_appcast --account com.gergoterek.HoverClick`.
- `scripts/package-dmg.sh` remains internal/test packaging and is not the appcast publishing workflow.

## Sparkle v0.9.0 Updater Completion

The v0.9.0 updater-completion branch keeps the manual update action and adds one user-controlled automatic-check preference.

- `Check for Updates...` remains the manual Sparkle update action.
- `Automatically Check for Updates` is a top-level native checkmark toggle.
- The toggle writes through Sparkle's `automaticallyChecksForUpdates` property and does not use a HoverClick-specific defaults key.
- `SUEnableAutomaticChecks` remains false, so the default state is off and Sparkle's automatic-check permission prompt is not introduced accidentally.
- `SUAutomaticallyUpdate` and `SUAllowsAutomaticUpdates` remain false.
- Toggling automatic checks reasserts `automaticallyDownloadsUpdates = NO`.
- Copied diagnostics report automatic update checks, automatic download/install, and whether automatic download/install is allowed.
- No appcast, release, DMG, tag, signing, bundle ID, app name, event tap, or mouse semantics work is part of this branch.
- Release prep for v0.9.0 sets `CFBundleShortVersionString = 0.9.0` and `CFBundleVersion = 38`; packaging, tag creation, GitHub Release asset upload, and appcast publication remain explicit release workflow steps after merge to `main`.

## Sparkle Appcast Release Workflow

The appcast release workflow is documented in `docs/APPCAST_RELEASE_WORKFLOW.md`.

- Recommended hosting: a dedicated `gh-pages` branch serving `appcast.xml` at the repository root for `https://gergoterek.github.io/HoverClick/appcast.xml`.
- GitHub Pages is configured from `gh-pages` branch root for the release appcast.
- `scripts/prepare-appcast.sh` is a non-publishing preflight/generation helper for releases. By default it performs a dry run and requires the real DMG path, final public GitHub Release asset URL, version, build, and output path.
- The helper uses pinned Sparkle 2.9.3 tooling from `tmp/sparkle/` and the Keychain account `com.gergoterek.HoverClick`; it must not receive, print, or commit private key material.
- Create or publish `appcast.xml` only after a real release DMG, release URL, and Pages location exist.
- For v0.9.0, the public DMG is `HoverClick-0.9.0.dmg`, the final release URL is `https://github.com/gergoterek/HoverClick/releases/download/v0.9.0/HoverClick-0.9.0.dmg`, and the appcast item must use version `0.9.0` / build `38`.
- Do not run `scripts/package-dmg.sh`, create a tag, create a GitHub Release, upload assets, or publish Pages output as part of appcast planning work.

## v0.9.0 Updater Completion Workflow

Implement v0.9.0 as the updater-completion and 1.0-readiness batch.

- Use `docs/V0.9.0_UPDATER_COMPLETION_PLAN.md` as the scope reference.
- Keep manual `Check for Updates...` as the primary update path.
- Automatic checks are explicit, user-controlled, reversible, and notification-only.
- Keep `SUAutomaticallyUpdate = false` and `SUAllowsAutomaticUpdates = false`.
- Do not package a DMG, create or move tags, create a GitHub Release, publish `gh-pages`, or modify `appcast.xml` outside an explicit release task.
- Do not implement real Hover Click Assist, Click-Time Hover Assist, mouse-move focus, synthetic clicks, event replay, cursor movement, delayed click delivery, scroll focus, or key focus.
- Remove the visible Hover Click Assist placeholder rather than shipping a no-op user-facing feature.

Implementation validation should include `git diff --check`, `scripts/ci-safety-check.sh`, `scripts/build-app.sh`, `scripts/verify-app.sh`, `scripts/run-app.sh`, and a final `scripts/verify-app.sh`. `scripts/run-app.sh` is the approved signed `.app` runtime refresh for this branch; do not run the raw binary directly.

## Release Scope

Release prep, DMG packaging, tags, and GitHub releases require explicit release-scope confirmation. `scripts/run-app.sh` is for local runtime refresh after build and verify, not for packaging or publishing.
