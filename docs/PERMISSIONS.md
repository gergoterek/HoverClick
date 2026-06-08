# Permissions

HoverClick needs macOS Accessibility permission so it can inspect the UI element under a click point, find the owning window, focus that window, and pass the original click through unchanged.

## App Identity

Accessibility permission belongs to the signed app bundle identity:

- App name: `HoverClick`
- Bundle identifier: `com.gergoterek.HoverClick`
- Signing identity: `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`

Stable signing matters because macOS uses the app identity when deciding whether Accessibility permission remains valid. Do not use ad-hoc signing for normal HoverClick builds.

Always launch HoverClick as the signed `HoverClick.app` bundle. Do not launch `HoverClick.app/Contents/MacOS/HoverClick` directly, because the raw binary launch path can confuse identity, permission, and diagnostics.

## First-Launch Setup

1. Launch HoverClick.
2. Open the HoverClick menu from the menu bar.
3. Open `Permissions & Startup`.
4. Choose `Open Accessibility Settings`.
5. In macOS Accessibility privacy settings, enable HoverClick.
6. Return to HoverClick and confirm the menu shows `Accessibility: Granted`.
7. If needed, quit and relaunch the normal signed app bundle.

Do not use privacy database resets for normal setup. Manage the permission from System Settings.

## Permission Behavior

The click event tap and Accessibility target resolution both require Accessibility permission. If permission is missing, HoverClick should stay open, keep click detection inactive, and show `Accessibility: Not Granted` from `Permissions & Startup`.

HoverClick does not require Screen Recording permission. It does not capture pixels, enumerate screen contents, record the display, send analytics, synthesize clicks, or move the cursor in the stable core.

## Menu Entries

`Permissions & Startup` contains:

- `Accessibility: Granted` or `Accessibility: Not Granted`
- `Launch at Login`
- `Open Accessibility Settings`

`Open Accessibility Settings` opens the Accessibility privacy pane only when the user clicks that menu item.

`Launch at Login` is separate from Accessibility permission. On macOS 13 and later, it uses the ServiceManagement main-app login item API. If macOS reports that user approval is required, HoverClick reflects that state instead of changing Accessibility permission.

## Troubleshooting

If clicks are not focused:

- Confirm `Accessibility: Granted`.
- Confirm `Left Click Focus` is enabled for left-click behavior.
- Confirm `Right Click Focus` is enabled if testing right-click behavior.
- Use `Diagnostics` > `Copy Diagnostics Summary` and check the permission and click detection lines.

If HoverClick does not appear in Accessibility settings:

- Confirm the app was launched as `HoverClick.app`.
- Keep the app in a stable location, such as Applications.
- Relaunch the signed app bundle and choose `Open Accessibility Settings` from the HoverClick menu.

If permission appears to be granted but behavior still fails, the target app may reject a specific Accessibility focus or raise operation. HoverClick logs those failures and still passes the original click through unchanged.
