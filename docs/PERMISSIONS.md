# Permissions

macOS Accessibility permission belongs to a signed app identity. For HoverClick, that identity is:

- App name: `HoverClick`
- Bundle identifier: `com.gergoterek.HoverClick`
- Signing identity: `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`

Stable signing is required because macOS uses the app identity when deciding whether the Accessibility permission remains valid. If the app is rebuilt with changing or ad-hoc signing, macOS can treat it as a different app and the permission can appear to reset.

Ad-hoc signing is not acceptable for this project. It is useful for quick local experiments, but it does not provide the stable developer identity needed for repeatable Accessibility trust across normal rebuilds.

The raw binary must not be launched directly. Launching `HoverClick.app/Contents/MacOS/HoverClick` bypasses the normal bundle launch path and can confuse identity, permission, and diagnostics. Always launch `HoverClick.app`.

The event tap and the Phase 2 Accessibility target resolution both require Accessibility permission. If Accessibility is missing, HoverClick should remain open, keep the event tap uninstalled, and show `Event Tap: Permission Missing` in the menu. The app should not repeatedly prompt or show custom permission alerts; use the menu item to open Accessibility settings when needed.

Phase 2 uses Accessibility to inspect the element under the cursor, find its window, raise that window, activate the owning app, and verify the result when macOS allows it. Some apps may reject specific AX attributes such as focused window or main window. Those failures are logged and are not treated as permission resets.

No Screen Recording permission is currently required. HoverClick does not capture pixels, enumerate screen contents, or record the display. Future features that inspect pixels or screenshots should document and request that permission separately.

This hardening pass does not add any permissions. It only improves nil checks, event tap lifecycle handling, transient UI ignores, and delayed verification diagnostics inside the existing Accessibility-based workflow.

Phase 3 Hover Focus does not add any permissions. It observes mouse movement through the existing Accessibility-trusted event tap and reuses the same AX target resolution and focus pipeline. No Screen Recording, Input Monitoring, or additional system permission is requested.

Coordinates are passed from `CGEventGetLocation` to `AXUIElementCopyElementAtPosition` unchanged. These APIs use the same global display point space for mouse events; Retina scaling does not require pixel conversion, and secondary displays may legitimately produce negative coordinates.

To grant permission:

1. Open System Settings.
2. Go to Privacy & Security.
3. Go to Accessibility.
4. Find HoverClick.
5. Turn HoverClick On.

The app also includes an `Open Accessibility Settings` menu item that opens the Accessibility privacy pane.
