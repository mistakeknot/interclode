---
name: delegate
description: Delegate tasks to Codex CLI agents for parallel autonomous execution. Use when facing independent bug fixes, implementation tasks, or test generation that can be done in parallel without shared state. Also works for single background tasks.
version: 0.2.2
---

# Cross-AI Delegation Skill

Delegate well-scoped tasks to Codex CLI agents (`codex exec`) for parallel autonomous execution. Claude Code acts as orchestrator — analyzing, dispatching, monitoring, reviewing, and verifying.

## When to Use

Use this skill when ANY of these are true:
- You have 2+ independent tasks that don't share state
- You have a single well-scoped task you want to run in the background while continuing other work in Claude Code
- Each task is well-scoped (clear input, clear success criteria)
- The tasks involve code changes (bug fixes, features, tests, refactoring)
- You can verify results independently (build, test)

## When NOT to Use

- Tasks requiring interactive user input mid-execution
- Tasks needing deep cross-file architectural understanding
- Code review (use interpeer instead)
- Tasks where you're unsure what needs to change (research first, then delegate)

## The Delegation Protocol

### Step 0: Fetch Codex CLI Reference

**BEFORE ANYTHING ELSE**: Fetch the current Codex CLI documentation so you have the latest flags and capabilities:

```
WebFetch: https://developers.openai.com/codex/cli/reference/
Prompt: "Extract all command line options, flags, their types, defaults, and subcommands for codex exec. Include global flags that apply to all subcommands."
```

This ensures you know about new Codex flags (e.g., `--search`, `--ask-for-approval`, `--no-alt-screen`) that may not be listed in dispatch.sh's passthrough yet. Use this knowledge when:
- Crafting dispatch commands (Step 3-4) — new boolean flags pass through dispatch.sh automatically; new value flags require calling `codex exec` directly
- Advising on sandbox modes and safety settings
- Debugging unexpected agent behavior

### Step 1: Identify Tasks

Look at the available work (beads, user request, context) and identify discrete units:

```
Task 1: [description] in [project/directory]
Task 2: [description] in [project/directory]
```

Present this plan to the user and get approval before dispatching.

### Step 2: Check for File Overlap

**BEFORE DISPATCHING**: Check if any two tasks touch the same files.

If two tasks might modify the same file, either:
- **(a) Combine them** into one agent prompt, or
- **(b) Dispatch sequentially** — agent 2 starts only after agent 1 commits

Parallel agents writing to the same file will create merge conflicts or silent overwrites. Always check.

### Step 3: Craft Prompts

Each prompt MUST include:
- **Context**: What the project is, relevant architecture
- **Task**: Exact description of what to fix/build/change
- **Files**: Specific files likely involved (give paths)
- **Success criteria**: How to verify (which tests, build command)
- **Constraints**: ALWAYS include the standard constraints below

**Prompt template:**
```
You are working on [project name], a [brief description].

## Task
[Detailed description of the specific task]

## Relevant Files
- [path/to/file1] — [what it does]
- [path/to/file2] — [what it does]

## Success Criteria
- [ ] [Exact build command] succeeds
- [ ] [Exact test command] passes
- [ ] [Specific behavior verified]

## Constraints (ALWAYS INCLUDE)
- Only modify files listed in "Relevant Files" unless absolutely necessary
- Do not reformat, realign, or adjust whitespace in code you didn't functionally change
- Do not add comments, docstrings, or type annotations to unchanged code
- Do not refactor or rename anything not directly related to the task
- Keep the fix minimal — prefer 5 clean lines over 50 "proper" lines
- If GOCACHE permission errors occur, use: GOCACHE=/tmp/go-build-cache

## Environment
- Run build with: [build command]
- Run tests with: [test command]
```

**Tip**: Use `--inject-docs` on dispatch.sh to auto-prepend the project's CLAUDE.md to the prompt. This injects Claude Code-specific instructions that Codex wouldn't otherwise see (Codex already reads AGENTS.md natively from the `-C` directory, so injecting AGENTS.md is redundant):
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name task1 -o /tmp/interclode-{name}.md \
  "## Task\n[just the task-specific parts]"
```

**For long prompts**, use `--prompt-file` to avoid shell escaping issues:
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name task1 -o /tmp/interclode-{name}.md \
  --prompt-file /tmp/task1-prompt.md
```

**To preview** the full command and injected prompt before executing:
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --dry-run --inject-docs -C /path/to/project \
  --name task1 -o /tmp/interclode-{name}.md \
  "prompt here"
```

### Step 4: Dispatch

Use the dispatch script for each task. Launch all agents in parallel:

```bash
# Agent 1
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name fix-auth -o /tmp/interclode-{name}.md \
  -s workspace-write \
  "prompt for task 1"

# Agent 2 (parallel)
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name add-tests -o /tmp/interclode-{name}.md \
  -s workspace-write \
  "prompt for task 2"
```

Use `run_in_background: true` on each Bash call and set `timeout: 600000` (10 minutes).

### Step 5: Monitor

Check progress every 60-90 seconds:
```bash
tail -c 2000 /tmp/interclode-fix-auth.md
```

Codex JSONL sessions are at `~/.codex/sessions/YYYY/MM/DD/`.

Signs of completion:
- Output file has substantive content (not just "thinking...")
- The codex process is no longer running

Signs of trouble:
- Process running >5 minutes with no output growth
- Test processes stuck at 0% CPU (may need `pkill`)

### Step 6: Verify

For EACH completed agent, run ALL of these (don't skip any):

```bash
# 1. Read what the agent did
cat /tmp/interclode-{name}.md

# 2. Check it compiles
go build ./relevant/package/...   # (or language equivalent)

# 3. Run tests
go test ./relevant/package/... -v   # (or language equivalent)

# 4. Review the diff
git diff -- relevant/files

# 5. Check for cosmetic-only changes — line counts should be proportional to task scope
git diff --stat

# 6. If diff is suspiciously large relative to task, investigate before accepting
```

**NEVER skip verification.** Codex agents can:
- Report success when tests actually fail
- Make cosmetic changes alongside functional ones
- Over-engineer simple fixes
- Introduce subtle bugs
- Touch files outside the specified scope

### Step 6b: Retry Failed Agents

If an agent fails or partially completes, you have two options:

**Resume the session** (continues where the agent left off — preserves all context):
```bash
# Find the session ID from ~/.codex/sessions/YYYY/MM/DD/
codex exec resume <SESSION_ID> "The tests are still failing because X. Fix only the Y function."

# Or resume the most recent session:
codex exec resume --last "Tests failed on Z. Try a different approach."
```

**Re-dispatch from scratch** (fresh start — better when the agent went down a wrong path):
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name fix-auth-retry -o /tmp/interclode-{name}.md \
  "Previous attempt failed because [reason]. [Updated, more specific prompt]"
```

**When to resume vs re-dispatch:**
- Resume when the agent was on the right track but hit a build/test issue
- Re-dispatch when the agent over-engineered, touched wrong files, or went in the wrong direction
- Always tighten the constraints in the retry prompt based on what went wrong

### Step 7: Report and Close

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

**Commit message format** (after all agents verified):
```
fix(scope): one-line summary

- Bullet 1: what changed and why
- Bullet 2: what changed and why

Fixes: Bead-xxx, Bead-yyy
Agents: codex exec (gpt-5.3-codex) via interclode, claude reviewed

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
Co-Authored-By: GPT-5.3-Codex <noreply@openai.com>
```

Close beads if applicable:
```bash
bd close <id1> <id2> --reason="Fixed by Codex agent, verified by Claude"
```

## Codex CLI Reference

The full, up-to-date Codex CLI reference was fetched in **Step 0**. Refer to that for the complete flag list.

Key flags for delegation:

| Flag | Purpose |
|------|---------|
| `-C, --cd <DIR>` | Working directory (required) |
| `-s, --sandbox <MODE>` | `read-only`, `workspace-write`, `danger-full-access` |
| `-o, --output-last-message <FILE>` | Save agent's final message |
| `-m, --model <MODEL>` | Override model |
| `-i, --image <FILE>` | Attach image (repeatable) |
| `--add-dir <DIR>` | Grant write access to additional directories |
| `--json` | JSONL output to stdout |
| `--full-auto` | Shortcut for `-s workspace-write` |

**Resume**: `codex exec resume --last "follow-up"` or `codex exec resume <SESSION_ID> "follow-up"`

**Multi-directory tasks**: Use `--add-dir` when a task needs to write outside `-C`:
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  -C /path/to/project -o /tmp/out.md \
  --add-dir /path/to/shared-lib \
  "Fix the interface mismatch between project and shared-lib"
```

**New/unknown Codex flags**: dispatch.sh passes unknown `-*` flags through as boolean (no value). If the fetched docs show a new **boolean** flag (e.g., `--search`), it works automatically. For new **value** flags, you'll need to update dispatch.sh's passthrough list or call `codex exec` directly:
```bash
# Boolean flag — works via dispatch.sh's catch-all
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  -C /path/to/project -o /tmp/out.md \
  --search "prompt here"

# Value flag — call codex exec directly to avoid dispatch.sh's parser
codex exec -C /path/to/project -o /tmp/out.md \
  --new-value-flag somevalue "prompt here"
```

## Common Issues

| Problem | Solution |
|---------|----------|
| GOCACHE permission denied | Add `GOCACHE=/tmp/go-build-cache` to prompt |
| Agent test hangs | Some tests need live APIs; `pkill -f "test.binary"` |
| Agent closes its own beads | Fine — verify the bead is actually done |
| Output file empty after completion | Check `~/.codex/sessions/` for the JSONL transcript |
| Agent reformats unrelated code | Note in review; revert cosmetic changes if distracting |
| Agent over-engineers the fix | Add "keep it minimal" + "prefer N lines over M lines" to constraints |
| Agent realigns whitespace | Add "do not reformat unchanged code" to constraints |
| Agent runs wrong tests | Specify exact test command in success criteria, not just "run tests" |
| Background notifications arrive late | Don't wait for them — poll output files directly with `tail -c` |
| Agent touches files outside scope | List files explicitly + "only modify listed files" in constraints |
| Two agents conflict on same file | Check file overlap before dispatching (Step 2) |
