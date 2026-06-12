# HoverClick

HoverClick gives macOS a more Windows-like click-to-focus feel.

When you click a background window, HoverClick focuses that window before the original click is delivered. Mouse movement alone never focuses windows. HoverClick is not AutoRaise.

The original click event is passed through unchanged: no synthetic clicks, no cursor movement, no replacement events, and no hover-to-window-focus behavior.

## Features

- `Left Click Focus`: enabled by default. Left-clicking a background window focuses it before the click continues.
- `Right Click Focus`: disabled by default. When enabled, right-clicking a background window focuses it before the normal right-click continues.
- `Launch at Login`: starts HoverClick automatically after login when supported by macOS.
- `Permissions & Startup`: shows Accessibility status, Launch at Login, and an explicit `Open Accessibility Settings` action.
- `Diagnostics`: includes `Verbose Diagnostics` and `Copy Diagnostics Summary` for issue reports.
- `About HoverClick...`: shows version, build, bundle ID, and a short app description.

HoverClick runs from the macOS menu bar and has no Dock icon.

## Requirements

- macOS 12 or later.
- Accessibility permission.
- A normally launched, signed `HoverClick.app` bundle.

Always launch HoverClick as `HoverClick.app`, not the raw executable inside the app bundle. macOS Accessibility permission belongs to the signed app bundle identity.

## Download And Install

HoverClick is currently distributed from GitHub. The latest validated release is `v0.4.6` / build `32`, with the public asset `HoverClick-0.4.6.dmg`.

You can also build the app locally from source.

After launching HoverClick:

1. Open the HoverClick menu from the menu bar.
2. Open `Permissions & Startup`.
3. Choose `Open Accessibility Settings`.
4. Enable HoverClick in macOS Accessibility privacy settings.
5. Return to the menu and confirm `Accessibility: Granted`.

If the app still shows `Accessibility: Not Granted`, quit HoverClick and relaunch the signed `HoverClick.app` bundle.

## How To Use

- Keep `Left Click Focus` checked for the normal Windows-like click-to-focus behavior.
- Enable `Right Click Focus` if you want right-clicks on background windows to focus the target before the context menu opens.
- Enable `Launch at Login` if you want HoverClick to start automatically.
- Use `Diagnostics` > `Copy Diagnostics Summary` when reporting a problem.

## Menu Overview

- `Left Click Focus`: toggles left-click focus behavior.
- `Right Click Focus`: toggles right-click focus behavior.
- `Hover` > `Hover Click Assist`: experimental placeholder. It is off by default and does not add cursor movement, synthetic clicks, delayed verification, or mouse-move focus.
- `Permissions & Startup` > `Accessibility`: shows whether macOS has granted Accessibility permission.
- `Permissions & Startup` > `Launch at Login`: toggles startup registration where supported.
- `Permissions & Startup` > `Open Accessibility Settings`: opens the macOS Accessibility privacy pane when clicked.
- `Diagnostics` > `Verbose Diagnostics`: toggles extra logs.
- `Diagnostics` > `Copy Diagnostics Summary`: copies version, permission, startup, feature, event tap, and safety details.
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

Create a local DMG:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh
```

The DMG workflow writes an ignored artifact under `dist/`. It is useful for local packaging and testing.

For development workflow details, see `docs/DEVELOPMENT.md`.

## Uninstall

1. Quit HoverClick from the menu.
2. If enabled, turn off `Launch at Login`.
3. Remove `HoverClick.app` from Applications or wherever you placed it.
4. If desired, remove HoverClick from Accessibility privacy settings manually in System Settings.
