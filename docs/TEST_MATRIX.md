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
| Background Finder window focuses | Manual Finder UI validation — not run automatically. Click a visible background Finder window. | Logs show target app Finder, target window, `AXRaise`, app activation, verification, and Finder becomes frontmost. |
| Background Chrome window focuses | Manual Finder UI validation — not run automatically. Click a visible background Chrome window. | Logs show target app Chrome, target window, action attempts, verification, and Chrome becomes frontmost. |
| Background iTerm window focuses | Manual Finder UI validation — not run automatically. Click a visible background iTerm window. | Logs show target app iTerm, target window, `AXRaise`, activation, delayed verification, and iTerm becomes frontmost. |
| Menu/status clicks are ignored | Click the menu bar or HoverClick status item. | Logs show the target was ignored as own app, menu, or status UI. |
| Current front app gets minimal action | Click the already-front app. | Logs show the target app is already frontmost and the event passes through. |
| No click behavior changes | Use normal clicks while the event tap is enabled. | The event tap returns the original event unchanged after any focus attempt. |
| No drag behavior changes | Drag windows, text selections, or sliders while the event tap is enabled. | Drag behavior remains unchanged. |
| No window movement or resize | Click background windows and drag normally. | HoverClick logs focus/raise/activation only; windows do not move or resize. |
| No synthetic click | Search source and test normal click behavior. | No `CGEventPost` or synthetic mouse event path exists; the physical click is passed through. |
| Menu items stay enabled | Open the status menu before and after toggling permission and event tap state. | Accessibility, Event Tap, Click-to-Focus, Verbose Diagnostics, Open Accessibility Settings, and Quit are not accidentally greyed out. |
| Multi-monitor negative coordinates | Manual Finder UI validation — not run automatically. Click windows on secondary displays that use negative coordinates, if available. | Logs show raw and converted coordinates, target lookup succeeds, and no Retina pixel conversion is needed. |
| Focus result is not a false positive | Review logs after a background-window click. | Success is based on target resolution plus action and verification logs, not only event observation. |
