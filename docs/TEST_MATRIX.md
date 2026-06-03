# Test Matrix

| Test | Method | Expected Result |
| --- | --- | --- |
| App launches as `.app` | Run `/Users/gergoterek/Movies/OBS/GPT/HoverClick/scripts/run-app.sh` | The app is opened through `HoverClick.app`, not the raw binary. |
| Exactly one instance runs | Run `scripts/run-app.sh`, then `scripts/verify-app.sh` | Verification reports exactly one HoverClick process. |
| Menu appears | Manual Finder UI validation — not run automatically. Check the macOS menu bar. | A HoverClick status item appears with permission, settings, and quit menu items. |
| Accessibility status is detected correctly | Use the status menu permission item before and after granting permission. | The menu item reports `Accessibility: Granted` or `Accessibility: Missing`, and logs report trusted `YES` or `NO`. |
| Signing identity is stable | Run `scripts/build-app.sh`, then `scripts/verify-app.sh`. | Codesign authority includes `Apple Development: rizsutt@gmail.com (MVQ5PX4679)`. |
| Rebuild does not change bundle identifier | Run `scripts/build-app.sh` repeatedly and verify `CFBundleIdentifier`. | Bundle identifier remains `com.gergoterek.HoverClick`. |
| Raw binary is never used | Inspect scripts and build commands. | Scripts launch only `HoverClick.app`; no script runs `Contents/MacOS/HoverClick` directly. |
| Phase 1 event tap installs when allowed | Grant Accessibility, then run `scripts/run-app.sh`. | The menu shows `Event Tap: Enabled` and stdout prints `HoverClick: event tap installed`. |
| Missing Accessibility is handled calmly | Remove or do not grant Accessibility, then launch the app. | The app remains open and the menu shows `Event Tap: Permission Missing` without repeated prompts. |
| Left mouse down is observable | With `Event Tap: Enabled`, click anywhere while watching the unified log. | Logs include `click received raw=(x,y) converted=(x,y)`. This is event detection only. |
| Disabling Event Tap stops logs | Click `Event Tap: Enabled` in the menu, then click elsewhere. | The menu shows `Event Tap: Disabled` and new left mouse down logs stop. |
| Enabling Event Tap restarts logs | Click `Event Tap: Disabled` while Accessibility is granted. | The menu returns to `Event Tap: Enabled` and left mouse down logs resume. |
| Duplicate event tap install is skipped | Click Accessibility status refresh while Event Tap is already enabled. | Logs include `event tap already installed; skipping duplicate install` and only one HoverClick process remains. |
| Event tap timeout disabled path | Manual stress validation only. If macOS disables the tap by timeout, watch logs. | Logs include `event tap disabled by timeout` and `event tap re-enabled after timeout` when user intent is still enabled. |
| Event tap user-input disabled path | Manual system validation only. If macOS disables the tap by user input, watch logs. | Logs include `event tap disabled by user input` and the menu reflects the actual tap state. |
| Hover Focus defaults off | Launch HoverClick after a fresh/default configuration. | Menu shows `Hover Focus: Off`; moving over background windows does not focus them. |
| Hover Focus toggle persists | Toggle `Hover Focus: On`, quit/relaunch, then toggle off again. | The menu title updates immediately and the setting persists through `NSUserDefaults`. |
| Hover Focus off preserves click focus | With `Hover Focus: Off`, click a background Finder/Chrome/iTerm window. | Click-to-focus still works, and mouse movement alone does not focus windows. |
| Hover Finder focus | Toggle `Hover Focus: On`, then hover over a background Finder window for about 250 ms. | Logs show a hover candidate, target Finder/window, hover-to-focus action, and delayed verification. |
| Hover Chrome focus | Toggle `Hover Focus: On`, then hover over a background Chrome window for about 250 ms. | Logs show target Chrome/window and hover delayed verification. |
| Hover iTerm focus | Toggle `Hover Focus: On`, then hover over a background iTerm window for about 250 ms. | Logs show target iTerm/window and hover delayed verification. |
| Hover Codex focus | Toggle `Hover Focus: On`, then hover over a background Codex window for about 250 ms. | Logs show target Codex/window and hover delayed verification. |
| Hover already-frontmost app | Hover over the current frontmost app. | Logs show `ignored reason=already-frontmost`; no repeated focus spam. |
| Hover same-target repeat | Keep the pointer still over the same target or make tiny movements. | Same-target hover refocus is suppressed for at least 750 ms, and tiny jitter under 6 px does not constantly reschedule. |
| Rapid mouse movement | Move quickly between apps while Hover Focus is on. | Debounce prevents focus flicker and avoids logging every raw mouse movement. |
| Event Tap off disables hover | Turn Event Tap off while Hover Focus is on. | Click-to-focus and hover-to-focus stop. |
| Event Tap on resumes hover conditionally | Turn Event Tap on while Hover Focus is on, then while it is off. | Hover resumes only when `Hover Focus: On`; click-to-focus resumes either way. |
| Background Finder window focuses | Manual Finder UI validation — not run automatically. Click a visible background Finder window. | Logs show target app Finder, target window, `AXRaise`, app activation, verification, and Finder becomes frontmost. |
| Background Chrome window focuses | Manual Finder UI validation — not run automatically. Click a visible background Chrome window. | Logs show target app Chrome, target window, action attempts, verification, and Chrome becomes frontmost. |
| Background iTerm window focuses | Manual Finder UI validation — not run automatically. Click a visible background iTerm window. | Logs show target app iTerm, target window, `AXRaise`, activation, delayed verification, and iTerm becomes frontmost. |
| Menu/status clicks are ignored | Click the menu bar or HoverClick status item. | Logs show the target was ignored as own app, menu, or status UI. |
| Popover and transient menu UI are ignored | Click menu, popover, or transient app UI when visible. | HoverClick passes the event through without stealing focus away from the current app. |
| Current front app gets minimal action | Click the already-front app. | Logs show the target app is already frontmost and the event passes through. |
| Rapid clicking between apps | Click quickly between Finder, Chrome, iTerm, and Codex. | Logs keep sequence ids distinct; delayed verification may report `newerClick=YES` without crashing or false success claims. |
| Target app disappears before delayed verify | Manual validation only. Quit or close a target app immediately after click-to-focus. | Logs report a stale target/app exit and HoverClick does not crash. |
| No click behavior changes | Use normal clicks while the event tap is enabled. | The event tap returns the original event unchanged after any focus attempt. |
| No drag behavior changes | Drag windows, text selections, or sliders while the event tap is enabled. | Drag behavior remains unchanged. |
| No window movement or resize | Click background windows and drag normally. | HoverClick logs focus/raise/activation only; windows do not move or resize. |
| No synthetic click | Search source and test normal click behavior. | No `CGEventPost` or synthetic mouse event path exists; the physical click is passed through. |
| No duplicate process or tap | Run `scripts/run-app.sh`, then `scripts/verify-app.sh`; refresh Accessibility status from the menu. | Exactly one app process is running, and duplicate event tap installs are skipped. |
| Menu items stay enabled | Open the status menu before and after toggling permission and event tap state. | Accessibility, Event Tap, Click-to-Focus, Verbose Diagnostics, Open Accessibility Settings, and Quit are not accidentally greyed out. |
| Multi-monitor negative coordinates | Manual Finder UI validation — not run automatically. Click windows on secondary displays that use negative coordinates, if available. | Logs show raw and converted coordinates, target lookup succeeds, and no Retina pixel conversion is needed. |
| Focus result is not a false positive | Review logs after a background-window click. | Success is based on target resolution plus action and verification logs, not only event observation. |
