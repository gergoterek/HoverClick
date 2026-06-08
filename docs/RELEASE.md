# Release Signing Requirements

This document records the requirements for a future public Developer ID signed and notarized HoverClick release. It is a planning document only; Developer ID signing, notarization, stapling, release packaging scripts, certificates, app identity, and Accessibility behavior are not implemented or changed here.

## Release Status

- An internal Apple Development signed DMG exists for local testing.
- A public Developer ID signed and notarized release is not implemented yet.

## Current Internal Packaging

`scripts/package-dmg.sh` is the current internal DMG packaging workflow. It builds HoverClick, verifies the signed app bundle, stages `HoverClick.app` with an `Applications` symlink, creates a compressed read-only DMG under `dist/`, and verifies the image with command-line checks.

The internal DMG filename for version `0.4.2` is:

```text
HoverClick-0.4.2-internal.dmg
```

This workflow uses the current Apple Development signing identity:

```text
Apple Development: rizsutt@gmail.com (MVQ5PX4679)
```

The internal DMG is for testing. It is not a Developer ID signed, notarized, stapled, public release artifact.

## Public Release Requirements

A future public release needs:

- Apple Developer Program membership.
- A Developer ID Application certificate installed and available for code signing.
- A Developer ID Installer certificate only if a `.pkg` installer is added later.
- `notarytool`.
- `stapler`.
- Apple notarization credentials, such as a Keychain profile or App Store Connect API key.
- Team ID.
- A separate release packaging script added in a future task.
- A separate clean test environment for first-launch Accessibility testing.

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

1. Keep the internal DMG workflow stable.
2. Add Developer ID release packaging on a separate branch.
3. Keep internal and release packaging scripts separate.
4. Build a Developer ID signed `HoverClick.app`.
5. Package a release DMG.
6. Submit the release artifact for notarization.
7. Staple the notarization ticket.
8. Validate on a clean user account, VM, or separate Mac.
9. Test first launch and Accessibility permission grant behavior.
10. Create a GitHub Release only after clean-environment validation passes.

## Future Script Naming

`scripts/package-dmg.sh` should remain the internal Apple Development packaging workflow.

A future task may add:

```text
scripts/package-release-dmg.sh
```

That future script may handle Developer ID signing, release DMG creation, notarization submission, and stapling.

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

The next implementation task should be:

```text
Add Developer ID Release Packaging Script
```

Do that only after the Developer ID Application certificate and notarization credential plan are available.
