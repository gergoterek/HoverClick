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
