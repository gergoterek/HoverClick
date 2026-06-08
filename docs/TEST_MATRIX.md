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
| Phase 1 event tap installs when allowed | Grant Accessibility, then run `scripts/run-app.sh`. | The menu shows `Event Tap: Enabled` and logs include `[HoverClick] event tap installed mode=pass-through-default`. |
| Missing Accessibility is handled calmly | Remove or do not grant Accessibility, then launch the app. | The app remains open and the menu shows `Event Tap: Permission Missing` without repeated prompts. |
| Left mouse down is observable | With `Event Tap: Enabled`, click anywhere while watching the unified log. | Logs include `[HoverClick] click #... received leftClickFocus=... experimentalHoverClickAssist=... raw=(x,y) converted=(x,y)`. This is event detection only. |
| Disabling Event Tap stops logs | Click `Event Tap: Enabled` in the menu, then click elsewhere. | The menu shows `Event Tap: Disabled` and new left mouse down logs stop. |
| Enabling Event Tap restarts logs | Click `Event Tap: Disabled` while Accessibility is granted. | The menu returns to `Event Tap: Enabled` and left mouse down logs resume. |
| Duplicate event tap install is skipped | Click Accessibility status refresh while Event Tap is already enabled. | Logs include `event tap already installed; skipping duplicate install` and only one HoverClick process remains. |
| Event tap timeout disabled path | Manual stress validation only. If macOS disables the tap by timeout, watch logs. | Logs include `event tap disabled by timeout` and `event tap re-enabled after timeout` when user intent is still enabled. |
| Event tap user-input disabled path | Manual system validation only. If macOS disables the tap by user input, watch logs. | Logs include `event tap disabled by user input` and the menu reflects the actual tap state. |
| Launch at Login menu item appears | Manual Finder UI validation — not run automatically. Open the HoverClick status menu. | `Launch at Login` appears as an independent menu item. |
| Launch at Login toggles on | Manual Finder UI validation — not run automatically. Click `Launch at Login`, close the menu, then reopen it. | The item remains checked when ServiceManagement reports the main app login item is enabled. |
| Launch at Login toggles off | Manual Finder UI validation — not run automatically. Click `Launch at Login` again, close the menu, then reopen it. | The item remains unchecked when ServiceManagement reports the main app login item is not registered. |
| Launch at Login requires approval | If macOS reports the login item requires user approval, inspect the menu/logs. | The menu uses a mixed state and logs `requires approval` without opening System Settings automatically. |
| Mouse movement over background window | Manual Finder UI validation — not run automatically. Move the pointer over a background Finder/Chrome/iTerm window without clicking. | No focus change occurs, and no hover-to-focus logs appear. |
| Mouse movement over current front app | Move the pointer within the current frontmost app. | Focus remains unchanged and no AX focus/raise/activate path runs from mouse movement. |
| Left click focus remains available | With `Left Click Focus: On`, click a visible background Finder/Chrome/iTerm window. | The target window focuses before click delivery and the original click event is passed through unchanged. |
| Right Click Focus defaults off | Launch HoverClick after a fresh/default configuration, then inspect the status menu. | `Right Click Focus` appears as an enabled, unchecked menu item. |
| Right Click Focus off preserves normal right-clicks | With `Right Click Focus` unchecked, right-click a visible background Finder/Chrome/iTerm window. | HoverClick does not run the focus path for the background target, the original right-click event passes through unchanged, and the normal context menu behavior is preserved. |
| Right Click Focus toggles independently | Toggle `Right Click Focus` while `Left Click Focus` stays on, then toggle `Left Click Focus` while `Right Click Focus` stays off or on. | Each setting updates independently; left-click focus remains controlled only by `Left Click Focus`, and right-click focus remains controlled only by `Right Click Focus`. |
| Right Click Focus on focuses background window | With `Right Click Focus` checked, right-click a visible background Finder/Chrome/iTerm window. | The target window focuses before right-click delivery, logs use the `right-click` trigger, the original right-click event passes through unchanged, and the normal context menu can appear. |
| Right Click Focus on preserves active-window context menu | With `Right Click Focus` checked, right-click inside the already-frontmost app. | HoverClick treats the target as already frontmost, returns the original right-click event unchanged, and the context menu opens normally. |
| Old persisted Hover Focus setting is ignored | Set or leave any previous `HoverFocusEnabled` user default, then launch HoverClick normally. | The old setting cannot re-enable mouse-move-to-focus behavior and no Hover Focus menu item appears. |
| Experimental Hover Click Assist defaults off | Launch HoverClick after a fresh/default configuration. | Menu shows `Experimental Hover Click Assist: Off`. |
| Experimental Hover Click Assist off is a hard-off switch | Manual Finder UI validation — not run automatically. With `Left Click Focus: On` and `Experimental Hover Click Assist: Off`, click a visible background Finder/Chrome/iTerm window while watching logs. | The target window may focus through the immediate left-click focus path, the original event passes through unchanged, logs include `experimentalHoverClickAssist=OFF` and `Experimental Hover Click Assist OFF: no assist path scheduled`, and no delayed verify, synthetic click, cursor movement, mouse-move, hover, Gmail, or animated-button assist path runs. |
| Experimental Hover Click Assist toggles independently | Toggle `Experimental Hover Click Assist` while `Left Click Focus` stays on, then toggle `Left Click Focus` while Experimental Hover Click Assist stays off or on. | Each menu title updates independently and left-click focus remains controlled only by `Left Click Focus`. |
| Experimental Hover Click Assist is inert in this checkpoint | Turn `Experimental Hover Click Assist: On`, then move over background windows and click normally. | No delayed verify, mouse-move focus, synthetic click, cursor movement, replacement event, or assist behavior occurs. Stable left-click focus still returns the original event unchanged. |
| Event Tap off disables left click focus | Turn Event Tap off, then click a background window. | Left-click focus stops because the tap is disabled. |
| Event Tap on resumes left click focus | Turn Event Tap on while Accessibility is granted. | Left-click focus resumes when `Left Click Focus: On`. |
| Right-click event tap remains click-only | Inspect source for right-click support. | Right Click Focus uses `kCGEventRightMouseDown`; no mouse-moved, scroll, synthetic click, cursor movement, replacement event, or delayed assist path is added. |
| Future scroll focus remains unimplemented | Inspect source for `kCGEventScrollWheel`, scroll focus toggles, or scroll focus handlers. | No scroll focus path exists during Phase 3 stabilization. |
| Independent trigger toggles stay separate | Inspect menus and source. | Current controls include Event Tap, Left Click Focus, Right Click Focus, and Experimental Hover Click Assist; Scroll Focus remains future work. |
| Background Finder window focuses | Manual Finder UI validation — not run automatically. Click a visible background Finder window. | Logs show target app Finder, target window, `AXRaise`, app activation, verification, and Finder becomes frontmost. |
| Background Chrome window focuses | Manual Finder UI validation — not run automatically. Click a visible background Chrome window. | Logs show target app Chrome, target window, action attempts, verification, and Chrome becomes frontmost. |
| Background iTerm window focuses | Manual Finder UI validation — not run automatically. Click a visible background iTerm window. | Logs show target app iTerm, target window, `AXRaise`, activation, immediate verification, and iTerm becomes frontmost. |
| Menu/status clicks are ignored | Click or right-click the menu bar or HoverClick status item. | Logs show the target was ignored as own app, menu, or status UI. |
| Popover and transient menu UI are ignored | Click menu, popover, or transient app UI when visible. | HoverClick passes the event through without stealing focus away from the current app. |
| Current front app gets minimal action | Click the already-front app. | Logs show the target app is already frontmost and the event passes through. |
| Rapid clicking between apps | Click quickly between Finder, Chrome, iTerm, and Codex. | Logs keep sequence ids distinct and no delayed verification is queued. |
| Target app disappears after click | Manual validation only. Quit or close a target app immediately after click-to-focus. | HoverClick does not crash, and no delayed verification callback runs. |
| No click behavior changes | Use normal clicks while the event tap is enabled. | The event tap returns the original event unchanged after any focus attempt. |
| No drag behavior changes | Drag windows, text selections, or sliders while the event tap is enabled. | Drag behavior remains unchanged. |
| No window movement or resize | Click background windows and drag normally. | HoverClick logs focus/raise/activation only; windows do not move or resize. |
| No synthetic click | Search source and test normal click behavior. | No `CGEventPost` or synthetic mouse event path exists; the physical click is passed through. |
| No duplicate process or tap | Run `scripts/run-app.sh`, then `scripts/verify-app.sh`; refresh Accessibility status from the menu. | Exactly one app process is running, and duplicate event tap installs are skipped. |
| Menu items stay enabled | Open the status menu before and after toggling permission and event tap state. | Accessibility, Event Tap, Left Click Focus, Right Click Focus, Experimental Hover Click Assist, Verbose Diagnostics, Open Accessibility Settings, and Quit are not accidentally greyed out. |
| Multi-monitor negative coordinates | Manual Finder UI validation — not run automatically. Click windows on secondary displays that use negative coordinates, if available. | Logs show raw and converted coordinates, target lookup succeeds, and no Retina pixel conversion is needed. |
| Focus result is not a false positive | Review logs after a background-window click. | Success is based on target resolution plus action and verification logs, not only event observation. |

## Stable Checkpoint Manual Validation

Manual Finder UI validation -- not run automatically.

The current stable checkpoint has been manually validated with:

- Left Click Focus works and returns the original left-click event unchanged.
- Right Click Focus works, focuses the target background window first, and returns the original right-click event unchanged so the normal context menu works.
- Launch at Login works.
- Mouse movement alone does not focus windows.
- Accessibility permission did not reappear.
- No synthetic click, cursor movement, `CGEventPost`, `CGDisplayMoveCursorToPoint`, `kCGEventMouseMoved`, or scroll-focus behavior exists.
