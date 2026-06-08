# Release Positioning

This document records the current GitHub/source-first distribution model and the optional future requirements for a polished Developer ID signed and notarized HoverClick binary release. Developer ID signing, notarization, stapling, release packaging scripts, certificates, app identity, and Accessibility behavior are not implemented or changed here.

## Release Status

- HoverClick is currently distributed as a GitHub/source-first macOS utility.
- Users should build locally from source and run the signed `.app` bundle.
- An internal/test Apple Development signed DMG exists for local/internal testing.
- A public Developer ID signed and notarized binary release is not available yet.
- There is no Mac App Store release and no signed `.pkg` installer.

Apple Developer Program membership is not required for the current GitHub/source-first project. Membership would be needed later for a polished Developer ID signed and notarized public binary release. Because Apple Developer Program membership is not wanted right now, that binary-release path is deferred.

## Current Distribution Model

Current:

- GitHub source repository.
- Build locally from source.
- Run the signed `HoverClick.app` bundle through the project script.
- Grant Accessibility permission through System Settings.
- Use the internal/test DMG only for local/internal testing.

Not current:

- Notarized public DMG.
- Developer ID signed public binary.
- Mac App Store release.
- Signed `.pkg` installer.
- Smooth double-click install flow for every Mac.

## Current Internal/Test Packaging

`scripts/package-dmg.sh` is the current internal/test Apple Development signed DMG packaging workflow. It builds HoverClick, verifies the signed app bundle, stages `HoverClick.app` with an `Applications` symlink, creates a compressed read-only DMG under `dist/`, and verifies the image with command-line checks.

The internal DMG filename for version `0.4.2` is:

```text
HoverClick-0.4.2-internal.dmg
```

This workflow uses the current Apple Development signing identity:

```text
Apple Development: rizsutt@gmail.com (MVQ5PX4679)
```

This is an internal/test DMG. It is Apple Development signed, not Developer ID signed, not notarized, not stapled, not a polished public installer, and not the main public release artifact.

## Optional Future Binary Release Requirements

A future polished public binary release would need:

- Apple Developer Program membership.
- A Developer ID Application certificate installed and available for code signing.
- A Developer ID Installer certificate only if a `.pkg` installer is added later.
- `notarytool`.
- `stapler`.
- Apple notarization credentials, such as a Keychain profile or App Store Connect API key.
- Team ID.
- A separate release packaging script added in a future task.
- A separate clean test environment for first-launch Accessibility testing.

This work is deferred. Do not add Developer ID signing, notarization, stapling, release packaging, signing identity changes, or app identity changes until that future path is explicitly chosen.

## Certificate Checklist

- [ ] Developer ID Application identity appears in `security find-identity -v -p codesigning`.
- [ ] Certificate common name is recorded.
- [ ] Team ID is known.
- [ ] No secrets are committed.
- [ ] No credentials are stored in project files.

## Notarization Credential Checklist

- [ ] `notarytool` exists.
- [ ] `stapler` exists.
- [ ] Keychain profile name is chosen.
- [ ] Credentials are stored in Keychain or external secure storage, not in this repository.
- [ ] No Apple ID password, app-specific password, API key, or issuer ID is committed.

## Accessibility And TCC Risk

HoverClick requires macOS Accessibility permission. That permission may be tied to the app's signing requirement, which includes code identity information used by macOS privacy controls.

Switching HoverClick from the current Apple Development signing identity to a Developer ID signing identity may require users to grant Accessibility permission again. Users should grant or re-grant permission through the normal System Settings Accessibility privacy flow.

Do not recommend `tccutil reset` as a normal troubleshooting or release step. Do not recommend `sudo` for Accessibility setup. Do not recommend launching the raw binary inside the app bundle; users should launch the signed `HoverClick.app` bundle.

## Recommended Future Release Flow

Only use this flow if the Developer ID/notarization path is explicitly resumed later.

1. Keep the internal DMG workflow stable.
2. Add Developer ID release packaging on a separate branch.
3. Keep internal and release packaging scripts separate.
4. Build a Developer ID signed `HoverClick.app`.
5. Package a release DMG.
6. Submit the release artifact for notarization.
7. Staple the notarization ticket.
8. Validate on a clean user account, VM, or separate Mac.
9. Test first launch and Accessibility permission grant behavior.
10. Create a binary GitHub Release only after clean-environment validation passes.

## GitHub Source-First Release Draft

This draft is for a possible GitHub release entry. Do not create a release from this document automatically.

```text
HoverClick v0.4.2

HoverClick is currently a source-first macOS utility published through GitHub. A notarized public binary release is not available yet.

Current release path:
- Clone the repository.
- Build locally from source.
- Run the signed HoverClick.app bundle.
- Grant Accessibility permission through System Settings.

Stable features:
- Left Click Focus defaults on.
- Right Click Focus defaults off.
- Launch at Login is available on supported macOS versions.
- The status menu includes Hover, Permissions & Startup, Diagnostics, and Copy Diagnostics Summary.

Safety and scope:
- Accessibility permission is required.
- No mouse-move focus.
- No synthetic clicks.
- No cursor movement.
- No CGEventPost.
- No CGDisplayMoveCursorToPoint.

Packaging note:
- If HoverClick-0.4.2-internal.dmg is attached later, it is an internal/test DMG.
- The internal/test DMG is Apple Development signed.
- The internal/test DMG is not notarized and is not a polished public installer.
```

## Future Script Naming

`scripts/package-dmg.sh` should remain the internal/test Apple Development signed DMG packaging workflow. It should not notarize, staple, or become a polished public installer.

A future task may add:

```text
scripts/package-release-dmg.sh
```

That future script may handle Developer ID signing, release DMG creation, notarization submission, and stapling if the optional future binary-release path is resumed.

Future public release DMGs should use this filename pattern:

```text
HoverClick-<version>-release.dmg
```

## Public Release Blockers

- No Developer ID Application certificate is installed on this Mac.
- No notarization credential or profile has been verified.
- No release packaging script exists.
- No notarized and stapled release artifact exists.
- No clean-environment Accessibility test has been completed.

## What Not To Do

- Do not change the bundle ID casually.
- Do not change the signing identity inside normal feature tasks.
- Do not reset TCC as a normal troubleshooting step.
- Do not commit secrets.
- Do not notarize from the internal packaging script.
- Do not mix release signing work with event tap, focus, or feature work.

## Next Recommended Task

There is no Developer ID/notarization implementation task recommended for the current GitHub/source-first release path.

If a polished public binary release becomes a priority later, the next implementation task would be:

```text
Add Developer ID Release Packaging Script
```

Do that only after Apple Developer Program membership, the Developer ID Application certificate, and the notarization credential plan are available.
