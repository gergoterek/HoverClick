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

## Fresh Accessibility Permission Flow Test

This is a manual release-readiness confidence test, not an automated script and not a normal development task. Run it only when someone intentionally wants to verify the first-time Accessibility flow, preferably in a safe fresh macOS user account or fresh manual-install scenario where HoverClick has not already been granted Accessibility permission.

This checklist is different from resetting permissions. Do not use `tccutil reset` for this normal flow test. Only consider a permission-reset test if the user separately and explicitly chooses that risk, understands it can affect local privacy permissions, and labels it as a risky reset-specific validation.

Manual Finder UI validation -- not run automatically.

1. Start from a fresh macOS user account, clean-user test account, or fresh manual-install environment when available. Do not disrupt a normal development machine just to force a first-run state.
2. Confirm the app under test is the signed `HoverClick.app` bundle, not `HoverClick.app/Contents/MacOS/HoverClick` or any other raw binary launch.
3. Confirm the bundle identifier remains `com.gergoterek.HoverClick`.
4. Confirm the signing authority remains `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`.
5. Launch the signed `HoverClick.app` bundle normally.
6. Observe the first-run Accessibility prompt or the `Permissions & Startup` Accessibility status. The status should be understandable and should not suggest destructive reset steps.
7. Grant Accessibility permission through the normal macOS System Settings flow when prompted or when using `Permissions & Startup` > `Open Accessibility Settings`.
8. Return to HoverClick, reopen the menu, and confirm `Permissions & Startup` shows `Accessibility: Granted`.
9. Confirm the HoverClick menu opens normally after permission is granted.
10. Confirm `Left Click Focus` is checked, then left-click a visible background window and verify it focuses before the original click continues.
11. Use `Diagnostics` > `Copy Diagnostics Summary` and confirm the summary reports the expected Accessibility granted state and event tap requested/object/source/validity/installed/enabled state.
12. Quit HoverClick from the menu, relaunch the signed app bundle normally, and confirm there is no unexpected repeat prompt after the permission has been granted.
13. Reopen the menu after relaunch and confirm `Permissions & Startup` still shows `Accessibility: Granted`.
14. Quit HoverClick from the menu when finished.

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
