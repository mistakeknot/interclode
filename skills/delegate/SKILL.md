---
name: delegate
description: Delegate tasks to Codex CLI agents for parallel autonomous execution. Use when facing multiple independent bug fixes, implementation tasks, or test generation that can be done in parallel without shared state.
version: 0.1.0
---

# Cross-AI Delegation Skill

Delegate well-scoped tasks to Codex CLI agents (`codex exec`) for parallel autonomous execution. Claude Code acts as orchestrator — analyzing, dispatching, monitoring, reviewing, and verifying.

## When to Use

Use this skill when ALL of these are true:
- You have 2+ independent tasks that don't share state
- Each task is well-scoped (clear input, clear success criteria)
- The tasks involve code changes (bug fixes, features, tests, refactoring)
- You can verify results independently (build, test)

## When NOT to Use

- Single tasks (just do them directly)
- Tasks requiring interactive user input mid-execution
- Tasks needing deep cross-file architectural understanding
- Code review (use interpeer instead)
- Tasks where you're unsure what needs to change (research first, then delegate)

## The Delegation Protocol

### Step 1: Identify Tasks

Look at the available work (beads, user request, context) and identify discrete units:

```
Task 1: [description] in [project/directory]
Task 2: [description] in [project/directory]
Task 3: [description] in [project/directory]
```

Present this plan to the user and get approval before dispatching.

### Step 2: Craft Prompts

Each prompt MUST include:
- **Context**: What the project is, relevant architecture
- **Task**: Exact description of what to fix/build/change
- **Files**: Specific files likely involved (give paths)
- **Success criteria**: How to verify (which tests, build command)
- **Constraints**: Patterns to follow, things to avoid

**Prompt template:**
```
You are working on [project name], a [brief description].

## Task
[Detailed description of the specific task]

## Relevant Files
- [path/to/file1] — [what it does]
- [path/to/file2] — [what it does]

## Success Criteria
- [ ] [Build command] succeeds
- [ ] [Test command] passes
- [ ] [Specific behavior verified]

## Constraints
- Follow existing code patterns
- Do not refactor unrelated code
- [Project-specific constraints]

## Environment
- If GOCACHE permission errors occur, use: GOCACHE=/tmp/go-build-cache
- Run tests with: [test command]
```

### Step 3: Dispatch

Use the dispatch script for each task. Launch all agents in parallel:

```bash
# Agent 1
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  -C /path/to/project \
  -o /tmp/interclode-task1.md \
  -s workspace-write \
  "prompt for task 1"

# Agent 2 (parallel)
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  -C /path/to/project \
  -o /tmp/interclode-task2.md \
  -s workspace-write \
  "prompt for task 2"
```

Use `run_in_background: true` on each Bash call and set `timeout: 600000` (10 minutes).

### Step 4: Monitor

Check progress every 60-90 seconds:
```bash
tail -c 2000 /tmp/interclode-task1.md
```

Codex JSONL sessions are at `~/.codex/sessions/YYYY/MM/DD/`.

Signs of completion:
- Output file has substantive content (not just "thinking...")
- The codex process is no longer running

Signs of trouble:
- Process running >5 minutes with no output growth
- Test processes stuck at 0% CPU (may need `pkill`)

### Step 5: Verify

For EACH completed agent, independently verify:

```bash
# 1. Read what it did
cat /tmp/interclode-task1.md

# 2. Check it compiles
go build ./relevant/package/...

# 3. Run tests
go test ./relevant/package/... -v

# 4. Review the diff
git diff -- relevant/files
```

**NEVER skip verification.** Codex agents can:
- Report success when tests actually fail
- Make cosmetic changes alongside functional ones
- Over-engineer simple fixes
- Introduce subtle bugs

### Step 6: Report and Close

Summarize results to the user with evidence:
```
## Delegation Results

### Task 1: [name] — SUCCESS
- Agent completed in ~Xs
- Build: clean
- Tests: N/N pass
- Code quality: [brief assessment]

### Task 2: [name] — NEEDS ATTENTION
- Agent completed but [issue]
- [What needs manual intervention]
```

Close beads if applicable:
```bash
bd close <id1> <id2> --reason="Fixed by Codex agent, verified by Claude"
```

## Codex CLI Reference

```bash
codex exec [OPTIONS] "PROMPT"

Key options:
  -C, --cd <DIR>          Working directory (required)
  -s, --sandbox <MODE>    read-only | workspace-write | danger-full-access
  -o, --output-last-message <FILE>  Save agent's final message
  -m, --model <MODEL>     Override model (default: from config.toml)
  --json                  JSONL output to stdout
  --full-auto             Shortcut for -s workspace-write

Resume a session:
  codex exec resume <SESSION_ID> "follow-up prompt"
  codex exec resume --last "follow-up prompt"

Code review:
  codex exec review --uncommitted "focus on error handling"
  codex exec review --base main "review this branch"
```

## Common Issues

| Problem | Solution |
|---------|----------|
| GOCACHE permission denied | Add `GOCACHE=/tmp/go-build-cache` to prompt |
| Agent test hangs | Some tests need live APIs; `pkill -f "test.binary"` |
| Agent closes its own beads | Fine — verify the bead is actually done |
| Output file empty after completion | Check `~/.codex/sessions/` for the JSONL transcript |
| Agent reformats unrelated code | Note in review; revert cosmetic changes if distracting |
