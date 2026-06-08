# HoverClick

HoverClick is a menubar-only macOS utility that focuses a background window immediately before your configured click is delivered.

HoverClick focuses a background window immediately before your left or right click is delivered, then passes your original click through unchanged.

HoverClick is currently published as a GitHub/source-first open-source macOS utility. A notarized public binary release is not available yet.

## Current Distribution Model

Current:

- GitHub source repository.
- Build locally from source.
- Internal/test DMG packaging for development and local testing.

Not current:

- Notarized public DMG.
- Developer ID signed public binary.
- Mac App Store release.
- Signed `.pkg` installer.

## What It Does

- Lets a left click focus a background window before the click continues.
- Optionally lets a right click focus a background window before the normal context menu click continues.
- Runs from the macOS menu bar with no Dock icon.
- Shows Accessibility permission, Launch at Login, and diagnostics from the status menu.
- Copies a diagnostics summary that is useful when reporting issues.

## What It Does Not Do

HoverClick is not AutoRaise.

- Moving the mouse over another window does not focus it.
- Only configured click actions trigger focus.
- No mouse-move hover focus is used.

HoverClick also does not synthesize clicks, move the cursor, move windows, resize windows, record the screen, or upload click data.

## Features

- `Left Click Focus`: on by default. A left click on a background window can focus that window before the original click is delivered.
- `Right Click Focus`: off by default. When enabled, a right click can focus the target window before the original right-click continues, so normal context menus can still appear.
- `Launch at Login`: starts HoverClick automatically after login on supported macOS versions.
- `Permissions & Startup`: shows Accessibility status, Launch at Login, and an explicit `Open Accessibility Settings` action.
- `Diagnostics`: includes `Verbose Diagnostics` and `Copy Diagnostics Summary`.
- `Hover Click Assist`: experimental placeholder under `Hover`. It is default off, not required for normal use, and currently adds no cursor movement, synthetic clicks, delayed verification, or mouse-move focus behavior.

## Requirements

- macOS 12 or later.
- macOS Accessibility permission for click detection and window focus.
- A normally launched, signed `HoverClick.app` bundle.

`Launch at Login` uses the modern ServiceManagement main-app login item API on macOS 13 and later. On older macOS versions, the menu item may be unavailable.

## Installation And First Launch

The recommended current path is to build HoverClick locally from the GitHub source repository:

1. Clone the repository.
2. Build the signed app bundle with `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh`.
3. Launch the signed `.app` bundle with `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh`.
4. Look for the HoverClick status item in the menu bar.
5. Open the HoverClick menu and grant Accessibility permission through System Settings.

Always run HoverClick as `HoverClick.app`. Do not run the raw binary inside the app bundle, because Accessibility permission belongs to the signed app bundle identity.

Because HoverClick does not currently have a Developer ID signed and notarized public binary release, do not expect a polished double-click installer flow for every Mac yet.

## Accessibility Permission Setup

1. Launch HoverClick.
2. Open the HoverClick menu from the menu bar.
3. Open `Permissions & Startup`.
4. Choose `Open Accessibility Settings`.
5. In macOS Accessibility privacy settings, enable HoverClick.
6. If HoverClick still reports `Accessibility: Not Granted`, quit and relaunch the normal signed app bundle.

Do not reset macOS privacy databases for normal setup. Permission should be managed from System Settings.

## How To Use

- Leave `Left Click Focus` checked for the normal click-to-focus behavior.
- Turn on `Right Click Focus` only if you want right-clicks on background windows to focus the target before the context menu opens.
- Use `Launch at Login` if you want HoverClick to start after login.
- Use `Diagnostics` > `Copy Diagnostics Summary` when reporting behavior that does not match expectations.

## Menu Overview

- Header: shows `HoverClick` and the visible app version, such as `v0.4.2`.
- `Left Click Focus`: toggles left-click focus behavior.
- `Right Click Focus`: toggles right-click focus behavior.
- `Hover` > `Hover Click Assist`: experimental placeholder, default off.
- `Permissions & Startup` > `Accessibility`: shows whether macOS has granted Accessibility access.
- `Permissions & Startup` > `Launch at Login`: toggles startup registration when supported.
- `Permissions & Startup` > `Open Accessibility Settings`: opens the macOS Accessibility privacy pane when clicked.
- `Diagnostics` > `Verbose Diagnostics`: toggles extra logs.
- `Diagnostics` > `Copy Diagnostics Summary`: copies version, permission, startup, click detection, feature state, and safety details.
- `Quit`: stops HoverClick until you launch it again.

## Known Limitations

- Some apps may reject specific Accessibility focus or raise requests. HoverClick passes the original click through even when a focus attempt cannot be completed.
- `Right Click Focus` is off by default because users may prefer the default macOS context-menu behavior on background windows.
- `Hover Click Assist` is visible but experimental and currently inert.
- HoverClick does not add Scroll Focus. macOS already supports background scrolling in many apps, and HoverClick currently observes only left and right mouse-down triggers.
- Internal/test Apple Development signed DMG packaging is available for local testing. It is not Developer ID signed, not notarized, and not a polished public installer.

## Troubleshooting

If HoverClick does not respond to clicks:

- Check `Permissions & Startup` and confirm `Accessibility: Granted`.
- Confirm `Left Click Focus` is checked for left-click behavior.
- Confirm `Right Click Focus` is checked if you are testing right-click focus behavior.
- Use `Diagnostics` > `Copy Diagnostics Summary` and review the permission, click detection, and feature states.

If HoverClick is not visible in Accessibility settings:

- Make sure you launched the signed `HoverClick.app` bundle, not the raw executable inside it.
- Keep the app in a stable location such as Applications, then launch it again and reopen Accessibility settings from the HoverClick menu.

If context menus do not behave as expected:

- Remember that `Right Click Focus` defaults off.
- With `Right Click Focus` off, HoverClick should pass right-clicks through without running the focus path.
- With `Right Click Focus` on, HoverClick tries to focus the target first and then returns the original right-click unchanged.

If Launch at Login does not start HoverClick:

- Open `Permissions & Startup` and check the `Launch at Login` state.
- macOS may require user approval before the login item becomes active.
- Launch at Login is separate from Accessibility permission, so enabling one does not enable the other.

If the menu or version seems old after a build:

- Quit the running HoverClick instance.
- Rebuild the app.
- Relaunch the signed `HoverClick.app` bundle.
- Check the header row for the visible version.

## Privacy

HoverClick runs locally. It uses macOS Accessibility APIs to inspect the element under the click point and focus the owning window when configured. It does not upload click data, record screen contents, send analytics, synthesize clicks, or move the cursor in the stable core.

## Uninstall

1. Quit HoverClick from the menu.
2. If enabled, turn off `Launch at Login`.
3. Remove `HoverClick.app` from Applications or wherever you placed it.
4. If desired, remove HoverClick from Accessibility privacy settings manually in System Settings.

## Development

Build the app bundle:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
```

Verify the built app:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

Create an internal/test Apple Development signed DMG:

```sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh
```

The internal/test DMG workflow builds and verifies the existing Apple Development signed app bundle, then writes an ignored artifact under `dist/`. It is useful for local/internal testing only; it is not notarized and is not a polished public installer.

For development workflow details, see `docs/DEVELOPMENT.md`.

## License

No license file is included yet. The source-first GitHub distribution should add one before broader public reuse is encouraged.
