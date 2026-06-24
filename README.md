# HoverClick

HoverClick is a small click-to-focus utility for macOS.

When you click a background window, HoverClick focuses and raises that window before delivering the original click. Mouse movement alone never focuses windows. The original click event passes through unchanged: no synthetic clicks, no cursor movement, no hover-to-focus behavior.

## Requirements

- macOS 12 or later
- Accessibility permission
- A signed `HoverClick.app` bundle — always launch as the bundle, not the raw executable

## Download and Install

The latest public release is `v1.2.0` / build `42`. Download from GitHub Releases. You can also build from source using `scripts/build-app.sh`.

After launching HoverClick:

1. Open the HoverClick menu from the menu bar.
2. Choose **Permissions** under **Access**.
3. Choose **Accessibility Settings**.
4. Enable HoverClick in macOS Accessibility privacy settings.
5. Return to the menu and confirm **Accessibility: Granted**.

If the app still shows **Accessibility: Required**, quit and relaunch the signed `HoverClick.app`.

## How to Use

- Keep **Left Click Focus** checked for normal Windows-like click-focus behavior.
- Enable **Right Click Focus** if you want right-clicks on background windows to focus the target window first.
- Enable **Launch at Login** (in **Permissions**) to start HoverClick automatically.
- Enable **Auto Check Updates** only if you want Sparkle to check periodically. HoverClick does not silently install updates.
- Use **Diagnostics** > **Copy Summary** when reporting a problem.

## Menu Overview

HoverClick runs as a status-bar item with no Dock icon. The menu is organized into sections:

**Functions:** Left Click Focus · Right Click Focus · Bypass Key

**Access > Permissions:** Accessibility status · Launch at Login · Refresh Status · Accessibility Settings

**Updates:** Check Now... · Auto Check Updates

**Info > Help:** GitHub · Contact · Release Notes · Uninstall...

**Info > Diagnostics:** Copy Summary · Verbose Mode

**About** · **Quit**

## Troubleshooting

- **Clicks don't focus:** Confirm **Accessibility: Granted** in Permissions and **Left Click Focus** is checked. Use **Copy Summary** for details.
- **Not visible in Accessibility settings:** Confirm you launched the signed `.app` bundle, not the raw executable. Keep the app in a stable location such as Applications.
- **Context menus:** **Right Click Focus** is off by default. When on, HoverClick focuses the target first and returns the original right-click unchanged.
- **Launch at Login not working:** macOS may require user approval. Check **Permissions** > **Launch at Login** status.

## Privacy and Safety

HoverClick runs locally and uses macOS Accessibility APIs only to focus the window under a click. It does not upload data, record screen contents, synthesize clicks, move the cursor, or focus windows from mouse movement.

Some apps may reject Accessibility focus requests. HoverClick still passes the original click through unchanged in those cases.

## Build From Source

```sh
scripts/build-app.sh   # build and sign HoverClick.app
scripts/verify-app.sh  # verify the built app
```

See `docs/DEVELOPMENT.md` for workflow details.

## Uninstall

1. Quit HoverClick from the menu.
2. Disable **Launch at Login** in Permissions if it is enabled.
3. Remove `HoverClick.app` from Applications.
4. Optionally remove HoverClick from Accessibility settings in System Settings.
