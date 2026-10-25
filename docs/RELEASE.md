# Release

How a HoverClick version ships and how installed copies update. Superseded on 2026-09-14 the
earlier source-first positioning; the reasoning is in `docs/DECISIONS.md` under that date.

## Distribution model

- Every version is a GitHub Release with two assets: `HoverClick-<version>.dmg` and
  `appcast.xml`.
- Installed copies update through Sparkle. `SUFeedURL` is
  `https://github.com/gergoterek/HoverClick/releases/latest/download/appcast.xml`, which
  GitHub redirects to the `appcast.xml` attached to the newest non-prerelease Release. No
  `gh-pages` branch and no separate publish commit are involved.
- Updates are verified by the Sparkle EdDSA signature in the appcast, not by Apple.
- The app is signed with the self-signed `HoverClick Dev` certificate and is not notarized.
  Gatekeeper warns on the first launch of a downloaded copy; the user opens it through
  System Settings, Privacy & Security, Open Anyway. Because the identity is stable, macOS keeps
  the Accessibility grant across updates. An ad hoc signature would lose it on every update.
- Automatic checks stay off (`SUEnableAutomaticChecks = false`); the user checks from the
  menu (`Check Now...`).

## Credentials

Both live in the login keychain and are created once by `scripts/setup-signing.sh`, which
needs the login password and therefore runs in Terminal, not from automation:

| credential | keychain item | backup |
|---|---|---|
| code signing identity `HoverClick Dev` | My Certificates | `~/Documents/HoverClick secrets/HoverClick-Dev-identity.p12` (+ password file) |
| Sparkle EdDSA private key | `https://sparkle-project.org`, account `com.gergoterek.HoverClick` | `~/Documents/HoverClick secrets/HoverClick-sparkle-eddsa-private-key.txt` |

Move the backup folder into a password manager or an encrypted disk. Nothing under
`.signing/` or `~/Documents/HoverClick secrets/` is ever committed. If the private key is lost
again, installed copies cannot be updated in place and need one manual reinstall; that is what
happened between `v1.2.1` and `v1.3.0`.

## Shipping a version

Numbers: `CFBundleShortVersionString` is the marketing version (`1.3.0`), `CFBundleVersion` is
the build number Sparkle compares (`45`). Both only go up.

1. Write `docs/release-notes/<version>.md` (Markdown; `##` headings and `- ` bullets become
   the appcast description).
2. `scripts/release.sh prepare --version 1.3.0 --build 45`
   Writes the version into `Info.plist`, runs the static gate, builds and signs the app,
   verifies the signature, packages and verifies `dist/HoverClick-1.3.0.dmg`, signs the DMG
   with `sign_update` and inserts the item into `appcast.xml`.
3. Review and commit `Info.plist`, `appcast.xml` and the release notes, then push.
4. `scripts/release.sh publish --version 1.3.0 --build 45`
   Checks that the commit is pushed and that the appcast item verifies against the DMG,
   creates the GitHub Release `v1.3.0` (this creates the tag) with both assets and checks that
   the feed URL serves the new appcast.
5. On an installed previous build: `Check Now...`, install, confirm the new build number in
   the menu and that Accessibility is still granted.

`scripts/release.sh build` runs step 2 without the Sparkle signing and the appcast, for a
local bundle to install as the "previous build" of an update test.

## Older scripts

`scripts/package-dmg.sh` and `scripts/prepare-appcast.sh` predate the pipeline and still
carry the old machine's path; `scripts/release.sh` does not use them.
