# Decision Log

Append-only. Newest entry on top. Never rewrite or delete an old entry — if a decision is
reversed, add a new entry that says so and link back.

This file is the project's long-term memory. Chats are disposable; this is not.

**Entry format**

```
## YYYY-MM-DD — Short title
**Decision:** what was chosen
**Why:** the reason
**Rejected:** what else was considered and why it lost
**Evidence:** command output, file:line, or "not verified"
```

---

## 2026-09-06 — Window first, application second in the focus path

**Decision:** `focusTargetApp:` directs focus at the clicked window before it calls
`-activateWithOptions:`. The 2026-08-30 entry below stays valid but was incomplete: removing
`kAXFrontmostAttribute` was necessary and not sufficient.

**Why:** `-activateWithOptions:` carries the application's own main window forward with it.
While that main window was still the sibling the user had focused earlier, activation raised
the sibling in front of whatever the user had on top, which is the symptom that survived
`93ae113`. Pointing the application at the clicked window first makes the clicked window the
one activation carries. `NSApplicationActivateAllWindows` was never in the option set and
stays out.

**Rejected:** Dropping `-activateWithOptions:` altogether and letting the user's own click
activate the application. It is the stronger cure, because activation is the only step that
addresses more than one window, but it gives up the guarantee that the menu bar and the
keyboard follow the clicked window before the click is delivered. Kept as the fallback if a
sibling window ever comes forward again.

**Evidence:** Runtime measurement 2026-09-06, macOS 26.6.2, locally built bundle from
`c700de2`, two Chrome windows with a third application in front. `click #37` at `14:44:04`:
`AXRaise success`, `focused window readback ... match=YES`, and the CGWindowList z-order
right after the click was clicked Chrome window, third application, sibling Chrome window.
One earlier sample in the same session (`click #34`) ended with both Chrome windows above the
front application; there the clicked window was already Chrome's main window and a second
user click landed one second later, so that sample is not attributable. See
`docs/PROJECT_STATE.md` for the follow-up.

---

## 2026-08-30 — Public Accessibility APIs can raise a single window

**Decision:** Closes the question opened on 2026-08-03. Public AX is sufficient. No private
SkyLight API is needed, and none will be added.

**Why:** Setting `kAXFrontmostAttribute` on the application element was the whole cause of
the multi-window symptom. That attribute has application scope and cannot address one window.
With it removed, `kAXFocusedWindowAttribute` on the application element plus `kAXRaiseAction`,
`kAXMainAttribute` and `kAXFocusedAttribute` on the window direct focus at the clicked window
alone, while `-activateWithOptions:` brings the application forward.

**Rejected:** Adopting `_SLPSSetFrontProcessWithOptions` or any other private SkyLight call.
The hypothesis that window managers need private APIs for this turned out not to describe
HoverClick's case: those tools reorder windows without activating the owning application,
which is a stronger requirement than what click-to-focus needs.

**Evidence:** Runtime test on 2026-08-30, macOS 26.6.2, locally built bundle from `93ae113`.
Two Chrome windows side by side, a third application frontmost, click on the visible edge of
the background Chrome window. Only the clicked window came forward; the sibling window kept
its z-order position. This is the first runtime verification performed on the current
machine. Static checks passed as well, but they cannot observe this behavior.

---

## 2026-08-27 — Signing certificate and Sparkle private key are gone

**Decision:** Recorded as fact, with the consequences left open. Do not plan a release, a
DMG, an appcast entry or a Sparkle update until the two questions below are answered.

**Why:** The project moved to a new machine after the previous one was compromised. The
repository survived intact and was reconstructed from a fresh clone; every recovered source
file matched its committed blob byte for byte, so no source work was lost. Two credentials
did not survive, and neither can be restored from the backup:

1. The `Apple Development` certificate the Makefile requires.
   `security find-identity -v -p codesigning` returns `0 valid identities found`.
2. The Sparkle EdDSA private key matching `Info.plist:SUPublicEDKey`
   (`093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o=`). The login keychain holds no
   `https://sparkle-project.org` item.

The second is the more serious one, because it reaches users rather than the workstation.
Installed `v1.2.1` copies validate updates against that public key. A new key pair cannot
produce a signature those copies will accept, so the existing update channel cannot be
continued, only abandoned or replaced by a manual reinstall.

Local development is not blocked. A locally built bundle runs and was used to verify the
focus fix at runtime on 2026-08-30. It is not distributable and does not carry the hardened
runtime, because library validation rejects a framework that does not share the main
executable's team identifier.

**Rejected:** Reusing anything from the backup as a substitute. Certificates and private
keys from a compromised machine are not reinstated even when a copy exists.

**Evidence:** Commands above, run 2026-08-30 on macOS 26.6.2. Recovery detail in
`_recovery/RECOVERY-REPORT-20260827.md`, which is local and not tracked.

**Still undecided:** the signing strategy for development and for release, and whether the
Sparkle update channel is rebuilt with a new key or retired.

---

## 2026-08-03 — In-menu tooltips were tried twice and reverted twice

**Decision:** Recorded, not reopened. Read this before any work that proposes replacing the
`Guide` submenu with hover tooltips.

**Why:** Native in-menu hover tooltips do not display on HoverClick's custom `NSView` menu
rows, for two independent reasons:

1. `rowView.toolTip = item.toolTip` is assigned at build time, before the row view has a
   window. The internal `addToolTipRect:owner:userData:` registers against no window and
   never fires. (`HoverClick.mm:536`, `HoverClick.mm:596`)
2. `NSMenu`'s modal tracking run loop does not drive `NSView` tooltip display at all, and
   `item.view` bypasses `NSMenuItem.toolTip` entirely.

Fixing reason 1 alone is not enough, and it was already attempted:

```
4fe9e91  fix: re-register tooltip in viewDidMoveToWindow for custom menu rows
135a786  Revert "fix: re-register tooltip in viewDidMoveToWindow for custom menu rows"
8103ab8  Revert "ui: add and update menu item tooltips"
```

Reason 2 cannot be closed without a hover timer, a global monitor, or a floating tooltip
window. All three are forbidden by `CLAUDE.md`.

The `Guide` submenu (`HoverClick.mm:1512`) is the deliberate replacement, chosen on
`research-menu-tooltips` after native tooltips failed manual testing. It has 8 rows built by
`HoverClickCreateQuickHelpItem`, adds no tracking areas, timers, monitors or event taps.

**Rejected:** reverting to plain `NSMenuItem`s (discards the whole custom-row system: icons,
toggles, non-closing rows, highlight, compact width); inline help rows in the main menu
(clutters it); a floating tooltip window (forbidden).

**Evidence:** `docs/CURRENT_STATE.md` sections "Tooltip baseline audit (2026-06-25)" and
"research-menu-tooltips (2026-06-25)". Source comment at `HoverClick.mm:642–649`. Branches
`ui-menu-tooltips` and `research-menu-tooltips` exist locally and on origin. Verified
2026-08-03 by reading source and git history; **not re-tested at runtime**.

---

## 2026-08-03 — Two working chats, not three

**Decision:** Development runs in two Claude Code chats — `BUILD` (implements, one branch,
disposable) and `REVIEW` (read-only, independent). A third chat is spawned ad-hoc for
research and closed when it produces an entry in this file.

**Why:** The proposed "Director" chat existed to hold cross-feature memory. A chat is the
worst place for that: context compaction destroys exactly that layer first. Files survive
compaction. The director role is the user plus `CLAUDE.md` + `PROJECT_STATE.md` + this file.

**Rejected:** A three-chat system with a permanent `00 Development Director`. It costs three
manual copy-paste handoffs per cycle for a single-developer project, and its central value —
remembering what was tried — is better served by an append-only file.

**Evidence:** Design decision, no measurement.

---

## 2026-08-03 — Local build and runtime testing stay in the workflow

**Decision:** Keep building and running the app locally. Do not adopt a source-only mode.

**Why:** Two prior audits reported the signing identity as broken and recommended a
source-only workflow with no build. Verified on this machine and the reports were wrong:

```
security find-identity -v -p codesigning
  1) 590F9A2A... "Apple Development: rizsutt@gmail.com (MVQ5PX4679)"
     notBefore=May  6 2026   notAfter=May  6 2027
codesign --verify --deep --strict HoverClick.app   → exit 0
```

The active bug is a window z-order behavior. Static review cannot tell whether a fix works,
and removing the app activation could silently break focus entirely while still passing every
static check.

**Rejected:** Source-only feature branches with runtime explicitly unverified. Legitimate in
general; wrong for this specific class of bug.

**Evidence:** Commands above, run 2026-08-03. Certificate chain intact
(Apple Development → WWDR → Apple Root CA).

---

## 2026-08-03 — Cause of the multi-window focus bug

**Decision:** Treat the two app-wide operations in `focusTargetApp:` as the primary suspects:
`activateWithOptions:` (`HoverClick.mm:4652`) and `kAXFrontmostAttribute` on the app element
(`HoverClick.mm:4677`). Both run before the target window is raised.

**Why:** The target window is resolved correctly as an `AXUIElement`, and the per-window
operations (`kAXRaiseAction`, `kAXMain`, `kAXFocused`) are correct. The app-wide calls happen
first and can reorder the whole process's window layer.

Separately, verification at `HoverClick.mm:4710` compares only
`frontAfter.processIdentifier == targetPid`. It is structurally incapable of detecting this
bug and will report `success` for the exact behavior being reported.

**Rejected:** Blaming Stage Manager, Rectangle, BetterTouchTool or Chrome. The user
reproduced it with all of those off, and in TextEdit.

**Evidence:** Source read at `HoverClick.mm:4586–4712`, 2026-08-03. **Not verified at
runtime** — no A/B build has isolated which of the two calls is responsible.

---

## 2026-08-03 — Open: can public AX raise a single window?

**Decision:** None yet. Blocking question for the focus fix.

**Why:** It is unconfirmed that public Accessibility APIs can raise one window of a background
app above another app's window without activating the app. Window managers such as yabai use
private SkyLight APIs (`_SLPSSetFrontProcessWithOptions`) for this, which suggests the public
path may be insufficient.

**Rejected:** Nothing yet.

**Evidence:** Hypothesis only. Resolve with an A/B experiment build before committing to an
implementation strategy. Record the answer as a new entry here.
