# Workflow

## Build And Verify

Use the signed app build script for local validation:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

`scripts/build-app.sh` creates `HoverClick.app`, copies bundled resources such as `Resources/HoverClick.icns` into `HoverClick.app/Contents/Resources/`, and signs the app with the configured Apple Development identity.

For the v0.8.0 Phase 1 updater branch, `Makefile` also downloads the official pinned Sparkle release `Sparkle-2.9.3.tar.xz` from `https://github.com/sparkle-project/Sparkle/releases/download/2.9.3/Sparkle-2.9.3.tar.xz` into the ignored `tmp/sparkle/` cache, verifies SHA-256 `74a07da821f92b79310009954c0e15f350173374a3abe39095b4fc5096916be6`, extracts `Sparkle.framework`, links it, embeds it in `HoverClick.app/Contents/Frameworks/`, and signs Sparkle's nested helpers plus the app with the existing Apple Development identity.

`scripts/verify-app.sh` checks the bundle identifier, icon declaration, bundled icon resource, Sparkle framework embedding/version/linkage/configuration/signing, signing identity, code signature verification, and process count.

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

For the v0.8.0 first-launch permission onboarding batch, manually cover in a safe fresh-user or fresh-install scenario when available:

- Launch the signed `.app` bundle with Accessibility not yet granted.
- Confirm HoverClick requests the native Accessibility trust prompt and shows its explanatory onboarding alert without opening System Settings automatically.
- Confirm `Left Click Focus`, `Right Click Focus`, `Hover`, and `Hover Click Assist` are disabled while Accessibility is missing.
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
- The appcast is future release infrastructure and may not be live yet.
- `SUPublicEDKey` is `093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o=`.
- The private EdDSA key is in the user's login Keychain under Sparkle account `com.gergoterek.HoverClick`; do not export it into the repository.
- Automatic checks and background automatic updates stay disabled by `SUEnableAutomaticChecks = false`, `SUAutomaticallyUpdate = false`, and `SUAllowsAutomaticUpdates = false`.
- Future appcast generation should use Sparkle tooling with the same Keychain account, for example `generate_appcast --account com.gergoterek.HoverClick`.
- `scripts/package-dmg.sh` remains internal/test packaging and is not the appcast publishing workflow.

## Release Scope

Release prep, DMG packaging, tags, and GitHub releases require explicit release-scope confirmation. `scripts/run-app.sh` is for local runtime refresh after build and verify, not for packaging or publishing.
