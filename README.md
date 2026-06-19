# HoverClick

HoverClick is a small click-to-focus utility for macOS.

When you click a background window, HoverClick can focus and raise that window before the original click is delivered. Mouse movement alone never focuses windows. HoverClick is not AutoRaise and does not focus windows just because the pointer passes over them.

The original click event is passed through unchanged: no synthetic clicks, no cursor movement, no replacement events, and no hover-to-window-focus behavior.

## Features

- `Left Click Focus`: stable and enabled by default.
- `Right Click Focus`: available and disabled by default unless you enable it.
- `Launch at Login`: starts HoverClick automatically after login when supported by macOS.
- `Permissions & Startup`: shows Accessibility status, `Check Again` / `Refresh Permission Status`, Launch at Login, and an explicit `Open Accessibility Settings` action.
- `Check for Updates...`: runs a manual Sparkle update check against the published appcast.
- `Automatically Check for Updates`: optional periodic Sparkle checks. It is off by default and does not enable automatic download or install.
- `Diagnostics`: includes `Verbose Diagnostics` and `Copy Diagnostics Summary` for issue reports.
- `About HoverClick...`: shows version, build, bundle ID, and a short app description.

HoverClick runs from the macOS menu bar, has no Dock icon, and includes a branded app icon in the app bundle.

## Requirements

- macOS 12 or later.
- Accessibility permission.
- A normally launched, signed `HoverClick.app` bundle.

Always launch HoverClick as `HoverClick.app`, not the raw executable inside the app bundle. macOS Accessibility permission belongs to the signed app bundle identity.

## Download And Install

HoverClick is currently distributed from GitHub. The latest public release is `v1.0.0` / build `39`.

`v0.5.0` adds the branded app icon, bundles `HoverClick.icns` in the signed app, and polishes the build, verify, runtime-refresh, README, and workflow documentation. It does not change runtime click-focus or event-tap behavior.

`v0.6.0` / build `35` adds packaging and DMG presentation polish. It does not change runtime click-focus or event-tap behavior.

`v0.7.0` / build `36` is the validated baseline before v0.8.0. It prepared Right Click Focus diagnostics/stability hardening, long-run click-focus diagnostics, and the narrow Window Server pointer-like overlay pass-through fix.

`v0.8.0` / build `37` adds the manual Sparkle `Check for Updates...` MVP, publishes the Sparkle appcast through GitHub Pages, keeps automatic Sparkle checks and background install disabled, adds first-launch Accessibility onboarding and permission-gated controls, refreshes permission state on launch/app activation/status menu open, fails open if Accessibility is revoked at runtime, adds Launch at Login consent onboarding, and expands Google Docs / Chrome click-through diagnostics. It does not add synthetic clicks, event replay, cursor movement, mouse-move focus, scroll focus, or event tap mask expansion.

`v0.9.0` / build `38` keeps manual `Check for Updates...`, adds a user-controlled `Automatically Check for Updates` toggle that defaults off, keeps automatic download/install disabled, removes the old no-op Hover Click Assist placeholder from the menu and diagnostics, and publishes the v0.9.0 DMG and appcast. It does not change click/event semantics.

`v1.0.0` / build `39` is the stable 1.0 release. It keeps the v0.9.0 click-focus, updater, Accessibility, diagnostics, and safety behavior unchanged, preserves conservative update settings, and publishes the public `HoverClick-1.0.0.dmg` release asset and appcast item.

You can also build the app locally from source.

After launching HoverClick:

1. Open the HoverClick menu from the menu bar.
2. Open `Permissions & Startup`.
3. Choose `Open Accessibility Settings`.
4. Enable HoverClick in macOS Accessibility privacy settings.
5. Return to the menu and confirm `Accessibility: Granted`.

If the app still shows `Accessibility: Required`, quit HoverClick and relaunch the signed `HoverClick.app` bundle.

## How To Use

- Keep `Left Click Focus` checked for the normal Windows-like click-focus behavior.
- Enable `Right Click Focus` if you want right-clicks on background windows to focus the target before the context menu opens.
- Enable `Launch at Login` if you want HoverClick to start automatically.
- Enable `Automatically Check for Updates` only if you want Sparkle to check periodically. Updates still use Sparkle's visible update flow; HoverClick does not silently install updates in the background.
- Use `Diagnostics` > `Copy Diagnostics Summary` when reporting a problem. It includes recent non-menu click-focus decisions and stable last real/background-click fields so menu clicks used to copy diagnostics do not hide the meaningful click path.

## Menu Overview

- `Left Click Focus`: toggles left-click focus behavior.
- `Right Click Focus`: toggles right-click focus behavior.
- `Permissions & Startup` > `Accessibility`: shows whether macOS has granted Accessibility permission.
- `Permissions & Startup` > `Check Again` / `Refresh Permission Status`: refreshes Accessibility permission state.
- `Permissions & Startup` > `Launch at Login`: toggles startup registration where supported.
- `Permissions & Startup` > `Open Accessibility Settings`: opens the macOS Accessibility privacy pane when clicked.
- `Check for Updates...`: checks the published Sparkle appcast manually; automatic checks and background install stay disabled.
- `Automatically Check for Updates`: toggles Sparkle automatic checks only; automatic download/install stay disabled.
- `Diagnostics` > `Verbose Diagnostics`: toggles extra logs.
- `Diagnostics` > `Copy Diagnostics Summary`: copies runtime permission, startup, feature, event tap, and safety details.
- `About HoverClick...`: shows HoverClick version, build, bundle ID, and a short description without opening external links.
- `Quit`: stops HoverClick.

## Troubleshooting

If clicks do not focus background windows:

- Confirm `Permissions & Startup` shows `Accessibility: Granted`.
- Confirm `Left Click Focus` is checked for left-click behavior.
- Confirm `Right Click Focus` is checked if you are testing right-click behavior.
- Use `Diagnostics` > `Copy Diagnostics Summary` and review the permission, click detection, and feature states.

If HoverClick is not visible in Accessibility settings:

- Confirm you launched the signed `HoverClick.app` bundle, not the raw executable.
- Keep the app in a stable location such as Applications.
- Relaunch HoverClick and reopen Accessibility settings from the menu.

If context menus do not behave as expected:

- `Right Click Focus` is off by default.
- With `Right Click Focus` off, right-clicks pass through without running the focus path.
- With `Right Click Focus` on, HoverClick focuses the target first and returns the original right-click unchanged.

If Launch at Login does not start HoverClick:

- Check `Permissions & Startup` > `Launch at Login`.
- macOS may require user approval before a login item becomes active.
- Launch at Login is separate from Accessibility permission.

## Privacy And Safety

HoverClick runs locally. It uses macOS Accessibility APIs to inspect the element under the click point and focus the owning window when configured.

HoverClick does not upload click data, record screen contents, synthesize clicks, move the cursor, move windows, resize windows, or focus windows from mouse movement alone.

Some apps may reject specific Accessibility focus or raise requests. When that happens, HoverClick still passes the original click through unchanged.

## Build From Source

Build the app bundle:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
```

Verify the built app:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

The build script copies `Resources/HoverClick.icns` into `HoverClick.app/Contents/Resources/` and signs the bundle with the configured Apple Development identity.

For development workflow details, see `docs/DEVELOPMENT.md`.

## Uninstall

1. Quit HoverClick from the menu.
2. If enabled, turn off `Launch at Login`.
3. Remove `HoverClick.app` from Applications or wherever you placed it.
4. If desired, remove HoverClick from Accessibility privacy settings manually in System Settings.
