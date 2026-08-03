# Handoff Templates

Keep every handoff short. The receiving chat reads the repository itself — it does not need
your transcript, your diff, or your logs.

---

## BUILD → REVIEW

```text
Branch:   fix/single-window-focus
Base:     f24f506 (main)
Commit:   <sha>

Changed:
- <one line per behavior change, not per file>

Files:
- <path> — <what changed there>

Checked:
- scripts/source-only-check.sh — PASS / FAIL
- scripts/build-app.sh — PASS / FAIL / not run
- runtime test — what was clicked, in which app, what happened

Risk:
- <what is still uncertain, or "none known">
```

---

## REVIEW → you

```text
Branch:   <name>
Commit:   <sha>

SCOPE:      PASS / FAIL
INVARIANTS: PASS / FAIL
STATIC:     PASS / FAIL
RUNTIME:    TESTED / NOT TESTED
VERDICT:    READY TO PUSH / NEEDS WORK

Findings (worst first, with file:line):
1. <finding>
2. <finding>

If nothing: "No actionable findings."
```

---

## Continuation — when a chat is full

Under 40 lines. Paste into the new chat of the same role, together with its starter prompt.

```text
Role:     BUILD / REVIEW
Branch:   <name>
HEAD:     <sha>
Task:     <one sentence>

Done:
- <what is finished and verified>

In progress:
- <what is half-done, in which file>

Decided (already written to docs/DECISIONS.md):
- <decision>

Next step:
- <the single next action>
```
