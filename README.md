# HoverClick

HoverClick is a small click-to-focus utility for macOS.

When you click a background window, HoverClick focuses and raises that window before delivering the original click. Mouse movement alone never focuses windows. The original click event passes through unchanged: no synthetic clicks, no cursor movement, no hover-to-focus behavior.

## Requirements

- macOS 12 or later
- Accessibility permission
- A signed `HoverClick.app` bundle — always launch as the bundle, not the raw executable

## Download and Install

The latest public release is `v1.2.1` / build `43`. Download from GitHub Releases. You can also build from source using `scripts/build-app.sh`.

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
- Keep **Background Hover** checked to see what the pointer rests on in a window that is not in front. A window of an app that is not active shows no hover feedback of its own, so HoverClick shows a small card instead: for a browser tab (Chrome, Chromium, Edge, Brave, Vivaldi, Opera) the tab's title with the site's address under it, for a button, link or image of any other app its name, with its help text or the link's site under it. Nothing is focused, so you can keep typing in the app you are in. The first time, macOS asks whether HoverClick may ask the browser for a tab's address; if you choose Don't Allow, the card shows the title alone. For a window with vertical tabs, HoverClick learns where the tab column is by checking the window's left edge at the pointer's height. Apps in **Excluded Apps** get no card, and apps that expose no names to Accessibility while in the background (Spotify, for one) show none either.
- Enable **Launch at Login** (in **Permissions**) to start HoverClick automatically.
- Enable **Auto Check Updates** only if you want Sparkle to check periodically. HoverClick does not silently install updates.
- Use **Diagnostics** > **Copy Summary** when reporting a problem.

## Menu Overview

HoverClick runs as a status-bar item with no Dock icon. The menu is organized into sections:

**HoverClick:** Left Click Focus · Right Click Focus · Background Hover · Bypass Key · Excluded Apps

**Access > Permissions:** Accessibility status · Launch at Login · Refresh Status · Accessibility Settings

**Updates:** Check Now... · Auto Check Updates

**Info > Guide:** short explanations of what each menu item does

**Info > Help:** GitHub · Contact · Release Notes · Uninstall...

**Info > Diagnostics:** Copy Summary · Verbose Mode

**About** · **Quit**

## Troubleshooting

- **Clicks don't focus:** Confirm **Accessibility: Granted** in Permissions and **Left Click Focus** is checked. Use **Copy Summary** for details.
- **Not visible in Accessibility settings:** Confirm you launched the signed `.app` bundle, not the raw executable. Keep the app in a stable location such as Applications.
- **Context menus:** **Right Click Focus** is off by default. When on, HoverClick focuses the target first and returns the original right-click unchanged.
- **Launch at Login not working:** macOS may require user approval. Check **Permissions** > **Launch at Login** status.
- **Maccy compatibility:** HoverClick automatically skips its focus behavior when you click a Maccy history item, so the paste always goes to the correct target app.
- **Excluded Apps:** Open **Excluded Apps** > **Add App Exclusion...** to pick an installed app from a list and exclude it from HoverClick focus behavior. Excluded apps appear by name and can be removed by clicking them. Maccy is always handled automatically for clipboard compatibility.

## Privacy and Safety

HoverClick runs locally and uses macOS Accessibility APIs to focus the window under a click and, with Background Hover on, to read the name of the tab, button, link or image under a resting pointer. It does not upload data, record screen contents, synthesize clicks, move the cursor, or focus windows from mouse movement.

Background Hover reads the pointer position on a timer, ten times a second, while an app other than the frontmost one is running. When the pointer rests for a third of a second over a window that is not in front, it reads through Accessibility the name, help text and link address of the control under the pointer, never its value, so text and field contents are not read. In a supported browser it reads the tab title in the browser's own tab area; to find a vertical tab column it looks at the window's top band and leftmost column. If another app's window covers the window there, that one look answers from that app and no card appears. It shows the name in a small card that clicks pass through and never focuses, raises or activates a window. Names are neither stored nor logged. For the site line under a tab's title HoverClick asks the browser itself for the titles and addresses of its open tabs (a read-only Apple Event, which macOS lets you allow or refuse per browser), keeps them in memory for at most 30 seconds to find the hovered tab's site, and shows only the host name. Addresses are never stored, logged or sent anywhere.

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
