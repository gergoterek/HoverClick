# Architecture

## Phase 0: Signed Menubar Shell

Create a stable, signed, menubar-only app bundle with a fixed bundle identifier and an Accessibility permission status check.

## Phase 1: Event Tap Permission Proof

Implemented a minimal listen-only `CGEventTap` proof for `kCGEventLeftMouseDown`. It validates Accessibility permission and event tap lifecycle behavior without changing click delivery, focusing windows, raising windows, or synthesizing events.

## Phase 2: Fast Click-To-Focus

Implemented fast click-to-focus behavior. The event tap now uses a pass-through default tap for `kCGEventLeftMouseDown` so HoverClick can attempt focus before returning the original event unchanged.

The callback remains pass-through: it never returns a replacement click event and never returns `NULL` for normal clicks. `NULL` is returned only for null event input; system tap-disabled pseudo-events return the received event after recovery handling. HoverClick does not synthesize clicks, move the cursor, move windows, or resize windows.

Event tap lifecycle guards:

- Installs only once and logs `event tap already installed; skipping duplicate install` when a duplicate install is requested.
- Logs `event tap disabled by timeout` or `event tap disabled by user input` for system-disabled pseudo-events.
- Checks Accessibility trust again inside the normal left/right mouse-down callback before entering AX hit-testing or focus logic. If permission is missing or revoked, the callback records permission-missing pass-through, schedules stale tap removal, performs no AX work, and returns the original event unchanged.
- Tracks user intent, tap object presence, CFMachPort validity, run loop source presence, run loop source validity, believed installed state, and believed enabled state separately.
- Re-enables the existing tap when the user still wants it enabled, the CFMachPort is valid, and the run loop source is valid, then logs `event tap re-enabled after ...`.
- Recreates the tap when disabled-event recovery finds a missing or invalid port/source, or when `CGEventTapEnable` does not leave the tap enabled.
- Removes the run loop source and CFMach port on app quit or menu disable.
- Logs `event tap remove requested but no active tap` for no-op cleanup.

For each click, HoverClick:

1. Reads the global click point from `CGEventGetLocation`.
2. Uses `AXUIElementCreateSystemWide` and `AXUIElementCopyElementAtPosition` to resolve the element under the cursor.
3. Reads the target pid and app name.
4. Records the topmost CoreGraphics window under the point for overlay diagnostics.
5. Uses AX hit-testing before treating a non-layer-0 CoreGraphics window as a hard skip.
6. Ignores HoverClick itself, menu roles, status items, protected menu-bar/system UI overlays, compact popup-style overlays, and unresolved targets.
7. Resolves a target window from `AXWindow` or by bounded `AXParent` climbing.
8. Attempts app activation, AX frontmost, `AXRaise`, and focused-window attributes.
9. Records frontmost-before, activation return value, AX operation results, and immediate front-app verification.
10. If immediate verification fails, schedules a short main-queue delayed verification diagnostic.
11. Returns the original event unchanged.

`observed leftMouseDown` from Phase 1 was only event observation. Phase 2 success requires target resolution plus a focus/raise action result.

Diagnostics intentionally remain detailed. Logs distinguish click receipt, AX element lookup, target pid/app/window resolution, ignored targets, `AXRaise`, app activation, immediate verification, delayed verification when immediate verification fails, event pass-through, tap creation, tap enable/disable, tap disabled/re-enabled/recreated recovery, and tap removal. Each click carries a monotonically increasing sequence id such as `click #42`.

`Diagnostics` > `Copy Diagnostics Summary` exposes the event tap lifecycle state needed for long-running failures: requested state, object/source presence, port/source validity, believed installed/enabled state, detected enabled state when available, last event tap callback type, last left/right mouse-down callback timestamps, and last recovery attempt/result. It also separates volatile last click handling from persistent background-focus diagnostics, including the last focus decision detail, the last right-click focus decision, the last background-focus attempt, trigger, target app, frontmost app before the attempt, activation return value, AX operation results, immediate frontmost app, delayed verification state, final result, failure reason, and last verified successful background focus. Later menu or overlay clicks may update the volatile last handled action, but they do not erase the stable last real/background click decision, recent non-menu mouse-down decision history, last focus decision detail, last right-click focus decision, last non-menu focus decision, last background-focus attempt, or last verified background-focus success. Overlay diagnostics record the last overlay/system UI skip reason, the topmost CoreGraphics owner/window/layer/title/bounds involved, the AX role/subrole/app seen at the click point, and the last eligible AX hit-test candidate when one is safely available. A narrow policy exception treats tiny untitled no-bundle high-layer Window Server surfaces near the click point as pass-through only when AX hit-testing resolves a normal non-menu app/window target underneath; this prevents cursor-like Window Server surfaces from blocking normal background focus while preserving actual menu/status/system UI skips. HoverClick must not ignore all Window Server windows globally, and this exception must not weaken real menu, status, popover, or system UI protection. The recent decision history keeps the latest 10 non-menu mouse-down decisions with sequence id, timestamp, trigger, click location, frontmost app before the click, topmost CG window summary, AX target summary, eligible-candidate state, policy decision or skip reason, overlay/system UI and compact-popup involvement, focus-attempt start, AX operation summary, immediate verification, delayed verification, and final result. Aggregate counters track mouse callbacks, left/right callbacks, non-menu decisions, focus attempts, successful verifications, policy skips, overlay/system UI skips, compact-popup skips, and HoverClick menu/status UI skips.

Delayed verification is diagnostic-only and runs only after immediate frontmost verification fails. It is scheduled on the main queue after the original event has been left unmodified; it does not sleep in the event tap callback, consume the event, synthesize clicks, replay events, move the cursor, or add hover-assist-like work.

## Chrome / Web Content Click-Through Diagnostics

The Google Docs missed-click investigation adds diagnostics only. The focus path still observes only left and right mouse-down events, resolves the AX target, optionally focuses the target app/window, and returns the original event unchanged.

Copied diagnostics now include a click-through investigation map that separates event tap health, callback observation, target detection, focus attempt, AX operation result, immediate and delayed verification, original-event pass-through, and app/web-content click handling. Recent non-menu decisions also record the source/frontmost app before the click, target bundle ID, whether the target is Chrome, target window title, already-frontmost state, explicit pass-through state, and a conservative browser/web-content note.

Chrome-specific diagnostics are limited to public app and AX information, primarily bundle ID `com.google.Chrome`, AX role/subrole/title, and window title. HoverClick may report a Google Docs or browser-web-content hint when those strings or roles are visible through AX, but it does not inspect Chrome internals, web pages, DOM state, editor state, pointer state, or hover state.

When diagnostics show Chrome target detection, activation and AX operations attempted, immediate or delayed frontmost verification passed, and original-event pass-through, any remaining Google Docs missed click is outside HoverClick's direct observation and is likely app/web-content-level readiness or hover/click handling for the same physical mouse-down. This branch intentionally does not implement a workaround.

## Phase 3: Hover Focus Removal

The earlier optional Hover Focus experiment has been removed. HoverClick is not an AutoRaise-style app and must not focus, raise, or activate windows merely because the pointer moves over them.

The stable Phase 3 behavior is:

1. The event tap observes click-down triggers only: `kCGEventLeftMouseDown` and `kCGEventRightMouseDown`.
2. Mouse movement is not tapped for focus behavior.
3. A left click may trigger the existing click-to-focus path when Left Click Focus is on.
4. A right click may trigger the same safe focus path only when Right Click Focus is on.
5. The original click event is returned unchanged.
6. No synthetic clicks, cursor movement, window movement, or window resizing are performed.

The old persisted Hover Focus defaults key is intentionally no longer read, so an existing saved setting cannot re-enable mouse-move-to-focus behavior.

## Stable And Experimental Paths

Stable Left Click Focus is the normal behavior and defaults ON. It focuses, raises, and activates a background window immediately before the original left-click event is delivered, then returns that original event unchanged.

Right Click Focus is an independent trigger and defaults OFF. It persists under `rightClickFocusEnabled`; when OFF, right-click events are returned unchanged without running the focus path, and copied diagnostics record that the right mouse down was observed but skipped because Right Click Focus was disabled. When ON, right-clicking a valid background window uses the same target-window filters, app activation, AX frontmost, `AXRaise`, immediate verification, and diagnostic delayed verification path as Left Click Focus, then returns the original right-click event unchanged so context menus remain normal. Copied diagnostics keep a right-click-specific decision line so manual tests can distinguish observation, target resolution, focus attempt, immediate or delayed verification, ineligible-target skips, and disabled-setting skips.

Finder context-menu follow-up handling is intentionally narrow. After a recent Finder right-click, if Finder is already frontmost when the next left-click arrives, HoverClick clears the short-lived Finder state and passes that left-click through before AX hit-testing, focusing, raising, or activation. This helps Finder context menus dismiss and lets Finder handle the follow-up click as natively as possible without synthetic click replay. HoverClick still does not force Finder actual selection; Finder may show a context-target highlight on right-click while keeping the previous actual selection.

The v0.9.0 updater-completion branch removes the visible no-op Hover Click Assist placeholder instead of implementing it. HoverClick still does not observe mouse movement, synthesize clicks, replay events, move the cursor, post replacement events, or schedule delayed assist behavior.

## OS Integration

Launch at Login is a menubar-only integration that uses `SMAppService.mainAppService` on macOS 13 and newer. It registers or unregisters the main app as the login item; no helper app is bundled, and the toggle does not change event tap, focus, updater, Accessibility, signing, or bundle identity behavior.

First-launch permission onboarding is native AppKit and Accessibility API integration only. When Accessibility is missing, HoverClick calls `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt` once for that launch, shows a native explanatory alert, leaves click detection inactive, and disables click-focus feature toggles until permission is granted. Non-prompting trust refresh runs on launch, when the app becomes active, and just before the status menu opens, so the menu and diagnostics follow permission changes without requiring an app restart. The explicit `Check Again` / `Refresh Permission Status` action remains the prompt-capable user action. The onboarding alert is retained as a non-modal alert and is closed automatically when a refresh sees Accessibility granted, avoiding stale permission-required UI and duplicate alert stacks. If Accessibility is revoked at runtime while a tap object still exists, the callback fails open before target resolution, returns normal mouse events unchanged, and the main queue removes the stale tap. `Open Accessibility Settings` remains an explicit user-click menu item; HoverClick does not open System Settings automatically during launch or validation.

Launch at Login onboarding is likewise explicit consent only. On macOS 13 and newer, if the main-app login item is not registered and the prompt has not already been shown, HoverClick asks whether to enable startup and stores that ask in the `launchAtLoginOnboardingPromptShown` user default. Registration happens only when the user chooses `Enable Launch at Login`; declining does not affect Accessibility permission or click-focus settings.

The status item uses a native template SF Symbol, `cursorarrow.click`, configured at 16 pt semibold/large scale inside a 23 pt `NSStatusItem`. The symbol remains vector-backed and template-tinted by AppKit for normal light/dark menu bar appearance. The branded app bundle icon is separate from the status item and is generated from `assets/HoverClickAppIcon-1024.png` into `Resources/HoverClick.icns`. The implementation avoids custom status windows, event monitors, or private menu bar APIs.

The status menu starts with one non-clickable custom header row: `HoverClick` on the left and `v<short-version>` on the right. Both labels use a disabled text color; the custom view uses a compact 24 pt height, starts at indentation level 0, and uses a shared 14 pt horizontal padding constant so the title's left margin matches the version label's right margin. The visible header version reads from `CFBundleShortVersionString` through the runtime version helper, with a generic fallback only for malformed bundle metadata. Build number is intentionally not shown in the header or Diagnostics submenu; `About HoverClick...` remains the single UI surface for full version/build. Header and status-item tooltips use stable, release-independent wording.

Feature toggles use stable titles with native macOS checked/unchecked menu item state rather than appending `On` or `Off` to the title. Left Click Focus, Right Click Focus, and Automatically Check for Updates stay at the top level. The updater toggle writes through Sparkle's `automaticallyChecksForUpdates` setting, while `SUAutomaticallyUpdate` and `SUAllowsAutomaticUpdates` remain false so automatic download/install stays disabled. Permission and login/startup items live under the `Permissions & Startup` submenu to keep the top-level menu compact; that submenu contains Accessibility status, permission refresh, Launch at Login, and ends with `Open Accessibility Settings` as an explicit user-click action. Submenu parent items do not carry tooltips, while child status/action items keep specific native `NSMenuItem` tooltip/help text. Non-toggle rows are kept at indentation level 0 with an off state; `Copy Diagnostics Summary`, `Open Accessibility Settings`, `Check for Updates...`, `About HoverClick...`, and `Quit` use left-slot action symbols with exactly 1 ASCII space of title padding, and Quit preserves Cmd+Q. `About HoverClick...` shows a small native informational alert with the current version, build, bundle identifier, and one-line description; it opens no browser, external links, Finder, or System Settings. Native AppKit menus may still reserve a shared checkmark gutter inside menus that contain checked toggle rows, and HoverClick avoids fragile all-custom menu workarounds. Technical runtime details such as click detection state, updater state, and last handled action are not persistent diagnostic rows; they are available through `Diagnostics` > `Copy Diagnostics Summary`. Custom tracking loops, focus-stealing help windows, hover timing controls, or hover event monitors should remain separate future work if native menu tooltips prove insufficient.

Intentional shipped behavior or UI changes should bump `CFBundleShortVersionString` and/or `CFBundleVersion` consistently with the scope of the change. Git checkpoint-only tasks and read-only audits should not change version/build metadata. Docs-only tasks should not change version/build metadata unless they intentionally document a shipped version-label change.

## Distribution Packaging

HoverClick is distributed from GitHub. The latest public release is v0.9.0 / build 38, and v1.0 is currently planned as a conservative readiness/polish release rather than a runtime feature release.

`scripts/package-dmg.sh` remains an internal/test DMG workflow. It uses the current Apple Development signing identity, is useful for local/internal testing, is not notarized, and is not a release-publishing path by itself.

The DMG packaging workflow rebuilds and verifies `HoverClick.app`, stages the signed app with an `Applications` symlink, copies the dedicated DMG volume icon resource `Resources/HoverClickDMGVolumeIcon.icns` as `.VolumeIcon.icns`, sets the custom volume icon flag on an intermediate writable DMG with command-line tooling, converts the result to a compressed read-only DMG, and mounts the final DMG with `hdiutil -nobrowse -noautoopen` for verification. Verification checks the mounted app bundle identifier, version, build, code signature, `Applications` symlink target, `.VolumeIcon.icns` source match, hidden icon-file flag, and custom volume icon flag.

The package does not attempt to customize the `.dmg` file's own pre-mount Finder icon. That icon would depend on local file metadata such as resource forks or extended attributes outside the disk image payload, so it is not considered a reliable distribution feature for a GitHub Release asset after upload/download. The supported icon polish is the mounted DMG volume icon.

DMG Finder window background and icon layout are intentionally not part of the automated packaging architecture. They should remain future optional polish unless they can be produced deterministically without Finder UI automation, GUI scripting, browser automation, or fragile external dependencies.

Developer ID signing, notarization, stapling, a Mac App Store release, and a signed `.pkg` installer are not part of the current architecture. They remain optional future distribution work.

v0.4.6 / build 32 is fully released, validated, and closed.

v0.4.7 / build 33 is a previous public release superseded by v0.5.0. Its scope was maintenance/UI/docs polish after v0.4.6: native `About HoverClick...` version/build/bundle ID/description, dynamic header `v<short-version>` from `Info.plist`, stable release-independent tooltip text, no separate copied-diagnostics Version line, and no separate Diagnostics submenu version/build row. It did not change runtime click-focus behavior, the event tap mask, app identity, bundle identifier, or signing identity.

v0.5.0 / build 34 added the branded app icon workflow without runtime behavior changes. `CFBundleIconFile` points to `HoverClick.icns`; `scripts/build-app.sh` copies `Resources/HoverClick.icns` into `HoverClick.app/Contents/Resources/` and re-signs with the same Apple Development identity after the resource copy; `scripts/verify-app.sh` verifies the icon declaration and bundled resource. Release prep, tagging, and GitHub release creation require explicit release-scope confirmation.

v0.6.0 / build 35 is a previous packaging and DMG presentation polish release. Its scope was internal DMG staging of `HoverClick.app`, an `Applications` symlink, `Resources/HoverClickDMGVolumeIcon.icns` as a dedicated `.VolumeIcon.icns` separate from the app icon, custom mounted-volume icon metadata verification, and mounted-DMG app metadata and signing verification from command-line tooling. It did not promise a custom pre-mount `.dmg` file icon, and it did not change runtime click-focus behavior, the event tap mask, Accessibility behavior, app identity, bundle identifier, or signing identity.

v0.7.0 / build 36 is superseded by v0.8.0. Its scope was Right Click Focus diagnostics/stability hardening, long-run click-focus diagnostics, and the narrow Window Server pointer-like overlay pass-through fix. It did not include Key Focus / Caps Lock Focus, a Hover Click Assist implementation, Click-Time Hover Assist, Excluded Apps, Scroll Focus, Finder selection hacks, synthetic clicks, event replay, cursor movement, or expanded event handling.

v0.8.0 / build 37 is superseded by v0.9.0. Its scope is Sparkle 2.9.3 manual `Check for Updates...`, GitHub Pages appcast publication, first-launch Accessibility onboarding, permission-gated controls, `Check Again` / `Refresh Permission Status`, runtime Accessibility revocation fail-open behavior, Launch at Login consent onboarding, and Google Docs / Chrome click-through diagnostics. Automatic Sparkle checks and background automatic install remain disabled. It does not change the event tap mask, synthesize clicks, replay events, move the cursor, change app identity, change the bundle identifier, or change the signing identity.

v0.9.0 / build 38 is the current public release and v1.0 readiness baseline. Its scope keeps manual `Check for Updates...`, adds a user-controlled `Automatically Check for Updates` toggle that defaults off through `SUEnableAutomaticChecks = false`, keeps automatic download/install disabled through `SUAutomaticallyUpdate = false` and `SUAllowsAutomaticUpdates = false`, publishes the public DMG as `HoverClick-0.9.0.dmg`, and updates the GitHub Pages appcast to version `0.9.0` / build `38` only after the GitHub Release asset exists. It removes the visible Hover Click Assist placeholder but does not add hover focus, mouse movement observation, synthetic clicks, event replay, delayed click delivery, cursor movement, scroll focus, app identity changes, bundle identifier changes, signing identity changes, or event tap mask changes.

v1.0 readiness polish is documentation and release-readiness work only unless a later explicit scope says otherwise. It should not change runtime code, event semantics, signing, app identity, version/build metadata, appcast publication, package workflow, tags, or GitHub Release assets.

## Trigger Scope

HoverClick currently focuses windows only from configured click-down triggers. It does not add Scroll Focus because macOS already supports background scrolling in many apps.

Current menu controls expose:

- Left Click Focus
- Right Click Focus
- Automatically Check for Updates

The event tap should continue to observe only the current stable click inputs: `kCGEventLeftMouseDown` and `kCGEventRightMouseDown`.

Modifier Key Focus / Hold-to-Focus remains a future idea only. The failed 35 ms background drag assist / activation-settle experiment must not be reused; any future background click-and-drag work needs a new explicit, very risky branch, separate approval, and no synthetic clicks, event replay, cursor movement, or expanded event tap mask unless that risk is explicitly accepted.

## Hover Click Assist Removal

Hover Click Assist is not part of the current product surface. The v0.9.0 updater-completion branch removes the default-off no-op placeholder from the menu and copied diagnostics. This is a UI/product-surface cleanup only: it does not add hover focus, mouse movement observation, cursor movement, synthetic clicks, replacement events, delayed click delivery, or any new event-tap trigger.
