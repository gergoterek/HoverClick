# Chat Workflow

Two working chats. Both are Claude Code sessions opened in the repository root, so
`CLAUDE.md` loads automatically in each.

```
        you
         │
         ▼
   ┌───────────┐   branch + commit    ┌────────────┐
   │   BUILD   │ ───────────────────► │   REVIEW   │
   │           │                      │            │
   │ 1 branch  │ ◄─────────────────── │ read-only  │
   │ disposable│    findings           │ independent│
   └───────────┘                      └────────────┘
         │                                  │
         └──────────► you decide ◄──────────┘
                          │
                          ▼
              docs/DECISIONS.md  (permanent memory)
```

---

## BUILD

Owns exactly one branch. Plans, edits, builds, tests, commits, pushes.

**Lifetime:** one branch. Close the chat when the branch is pushed or abandoned.
This is the main defence against context growth — the next feature starts clean.

**May:** read source, edit source, run `source-only-check.sh`, `build-app.sh`,
`verify-app.sh`, `run-app.sh`, create the branch, commit, push when asked.

**May not:** merge to `main`, tag, package, edit the appcast, delete branches,
start a second unrelated feature, refactor beyond the task.

---

## REVIEW

Reads the actual branch and diff — never trusts the BUILD chat's summary.

**Lifetime:** one large feature, or two small ones. Replace after that.

**May:** read anything, run `git diff`, run `source-only-check.sh`, build and run the app
to reproduce a claim.

**May not:** edit files, commit, push, merge, or change scope.

**Must report:**

```
SCOPE:     PASS / FAIL — only the intended files changed
INVARIANTS: PASS / FAIL — the six hard rules in CLAUDE.md
STATIC:    PASS / FAIL — source-only-check.sh
RUNTIME:   TESTED / NOT TESTED — and what exactly was clicked
VERDICT:   READY TO PUSH / NEEDS WORK
```

`RUNTIME: NOT TESTED` is an honest answer. A static PASS reported as a working fix is not.

---

## RESEARCH (optional, ad-hoc)

Spawn only for an open technical question with no obvious answer — for example
"can public AX raise a single window without activating the app?".

Ends by writing one entry into `docs/DECISIONS.md`. Then close it.
Never let it accumulate implementation work.

---

## Handoff

Between chats you pass **five lines only** — never a full transcript, never a full diff.
The receiving chat reads the repository itself.

```
Branch:   fix/single-window-focus
Commit:   <sha>
Changed:  what behavior is different now
Checked:  which checks ran and their result
Risk:     what is still uncertain
```

The template lives in `docs/HANDOFF.md`.

---

## When to start a fresh chat

Deterministic rules — no guessing about context size:

- **Always** when starting a new branch (BUILD).
- When a second unrelated feature would enter the same chat.
- When you have pasted two or more long logs or diffs.
- When the chat can no longer state its branch, HEAD, or task without checking.

Claude Code shows real context usage with `/context`. Use that number, not a guess.

Before closing a chat, make sure anything worth remembering is in `docs/DECISIONS.md`
or `docs/PROJECT_STATE.md`. Nothing else survives.
