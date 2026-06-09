# Release Test Plan

This plan is for local validation before tagging or publishing a GitHub/source-first HoverClick release. It complements the static GitHub Actions safety checks; it does not replace manual app behavior testing.

## Scope

Validate the current local release candidate for:

- Signed local build and verification.
- Internal/test DMG packaging.
- First launch and Accessibility onboarding.
- Left Click Focus and Right Click Focus behavior.
- Menu, diagnostics, Launch at Login, and inert Hover Click Assist expectations.
- Local performance sanity while the app is already running.

This plan does not add Developer ID signing, notarization, stapling, app features, app identity changes, event tap changes, or Accessibility database changes.

## Preconditions

- Work from a clean task branch or reviewed release candidate.
- Confirm `Info.plist` still reports bundle identifier `com.gergoterek.HoverClick`.
- Confirm the visible version and build are the intended release values.
- Confirm the signing identity remains `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`.
- Use normal macOS Accessibility settings for permission management.
- Do not use `sudo` for release testing.
- Do not use `tccutil reset` for release testing.
- Do not launch the executable inside the app bundle directly.

## Build And Verify

Run:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/build-app.sh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/verify-app.sh
```

Expected:

- `HoverClick.app` exists.
- `CFBundleIdentifier` is `com.gergoterek.HoverClick`.
- Codesign verification passes.
- Codesign authority includes `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`.

## Internal DMG Packaging Test

Run manually:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/package-dmg.sh
```

Expected:

- An internal/test DMG is created under `dist/`.
- The DMG verifies with the script's command-line checks.
- The mounted image contains `HoverClick.app` and an `Applications` symlink.
- The DMG remains internal/test only. It is not Developer ID signed, not notarized, not stapled, and not a polished public installer.
- Generated artifacts under `dist/` and `tmp/` remain untracked.

## First Launch Test

Manual Finder UI validation -- not run automatically.

Launch the signed app bundle through the project script only when doing a manual UI test:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh
```

Expected:

- HoverClick appears as a menu bar status item.
- No Dock icon appears.
- The menu header shows `HoverClick` and the expected visible version.
- Exactly one HoverClick process is running when checked with `scripts/verify-app.sh`.
- The app is launched as the signed `.app` bundle, not the executable inside the bundle.

## Accessibility Permission Test

Manual Finder UI validation -- not run automatically.

Steps:

1. Open the HoverClick menu.
2. Check `Permissions & Startup` > `Accessibility`.
3. If permission is missing, choose `Open Accessibility Settings` only by explicit user click.
4. Grant permission through normal System Settings flow if needed.
5. Return to HoverClick and confirm the menu reports `Accessibility: Granted`.

Expected:

- Missing permission is reported calmly.
- HoverClick does not repeatedly prompt.
- Permission is managed through System Settings.
- Do not use `sudo`.
- Do not use `tccutil reset`.

## Menu/UI Test

Manual Finder UI validation -- not run automatically.

Expected menu structure:

- Header: `HoverClick` and the visible version.
- `Left Click Focus`.
- `Right Click Focus`.
- `Hover` > `Hover Click Assist`.
- `Permissions & Startup` with Accessibility status, Launch at Login, and `Open Accessibility Settings`.
- `Diagnostics` with `Verbose Diagnostics` and `Copy Diagnostics Summary`.
- `Quit`.

Expected behavior:

- Toggle titles stay stable and do not append `On` or `Off`.
- Toggle state uses native checkmarks.
- Technical click detection details are not persistent menu rows.
- `Open Accessibility Settings` opens settings only when clicked explicitly.

## Left Click Focus Test

Manual Finder UI validation -- not run automatically.

Expected:

- With `Left Click Focus` ON, left-clicking a visible background window focuses it before the original click is delivered.
- With `Left Click Focus` OFF, background left-click focus is disabled and the app does not run the left-click focus path.
- Dragging windows, selecting text, and using sliders still behave normally.
- Moving the mouse alone never focuses windows.

## Right Click Focus Test

Manual Finder UI validation -- not run automatically.

Expected:

- With `Right Click Focus` ON, right-clicking a visible background window focuses it and the normal context menu can open.
- With `Right Click Focus` OFF, background right-click behaves like normal macOS background right-click and does not run the focus path.
- Right Click Focus remains independent from Left Click Focus.
- Active-window context menus still work normally.

## Hover Submenu / Hover Click Assist Expectation

Manual Finder UI validation -- not run automatically.

Expected:

- `Hover Click Assist` is presented as experimental.
- It is not treated as stable behavior.
- It is inert in the current build.
- It does not move the cursor.
- It does not synthesize clicks.
- It does not focus windows from mouse movement.
- It does not add delayed verification or replacement event behavior.

## Launch At Login Test

Manual Finder UI validation -- not run automatically.

Steps:

1. Open `Permissions & Startup`.
2. Toggle `Launch at Login` ON.
3. Close and reopen the menu; confirm the state updates.
4. Toggle `Launch at Login` OFF.
5. Close and reopen the menu; confirm the state updates.
6. If practical, perform a later manual login test to confirm the setting persists.

Expected:

- Menu state follows the ServiceManagement status.
- If macOS reports user approval is required, HoverClick reflects that state.
- Launch at Login changes do not change Accessibility permission, event tap behavior, signing, or bundle identity.

## Diagnostics Test

Manual Finder UI validation -- not run automatically.

Expected:

- `Diagnostics` > `Copy Diagnostics Summary` copies useful status, including version, Accessibility state, startup state, click detection state, feature states, event tap mask, and safety notes.
- Diagnostics are understandable enough for issue reports.
- Diagnostics are not noisy or confusing during normal use.
- Extra log noise should appear only when `Verbose Diagnostics` is enabled.

## Performance Sanity Test

Performance testing is local/manual and is not fully automated in CI. The GitHub Actions workflow performs static repository safety checks only; it does not launch the app, build a signed app, package a DMG, or measure runtime performance.

After HoverClick is already running, collect a short snapshot:

```zsh
/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/performance-snapshot.sh
```

Expected:

- Idle CPU is normally low after the app settles.
- Memory does not continuously grow during a short test.
- The app does not feel laggy during normal click-focus use.
- There are no visible repeated permission prompts.
- There are no repeated noisy diagnostics unless `Verbose Diagnostics` is enabled.

Any rough CPU or memory concern should be treated as a heuristic that needs repeat observation, not a hard pass/fail threshold.

## Regression Safety Checklist

Before release, confirm:

- Event tap mask remains `CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)`.
- No mouse-move focus behavior.
- No scroll-focus behavior.
- No synthetic clicks.
- No cursor movement.
- No replacement mouse events.
- No `CGEventPost`.
- No `CGDisplayMoveCursorToPoint`.
- No app name, bundle identifier, signing identity, certificate, or version change unless the release intentionally includes that change.
- Generated artifacts remain untracked.
- `/bin/zsh scripts/ci-safety-check.sh` passes.

## Pass/Fail Release Decision

Pass the release candidate only when:

- Build, verification, and static safety checks pass.
- Manual first-launch, Accessibility, menu, focus, diagnostics, and Launch at Login checks pass or have clearly documented platform-specific exceptions.
- Internal/test DMG packaging passes when an internal DMG is part of the release candidate.
- Performance sanity checks do not show obvious runaway CPU, continuous memory growth, repeated permission prompts, or sluggish click behavior.
- The release candidate still matches the intended source-first distribution model.

Fail or hold the release candidate when:

- Runtime safety invariants change unexpectedly.
- Permission behavior requires privacy database resets or privileged commands.
- The app cannot be verified with the expected signing identity.
- Generated artifacts are staged or tracked.
- Manual testing finds focus, menu, diagnostics, or Launch at Login regressions.
