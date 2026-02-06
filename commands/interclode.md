---
name: interclode
description: Dispatch Codex agents for parallel autonomous work
---

# Interclode — Cross-AI Delegation

Dispatch one or more Codex CLI agents to work on tasks in parallel, then review their results.

## Usage

The user invokes `/interclode` with either:
- A description of tasks to delegate (you figure out how many agents and what prompts)
- A bead ID or list of bead IDs to work on
- No arguments (you analyze the current context and suggest delegations)

## Workflow

### 1. Analyze and Plan

Determine what work to delegate. Good candidates for Codex delegation:
- Bug fixes with clear reproduction steps
- Well-scoped implementation tasks
- Test generation for existing code
- Refactoring with clear boundaries

**Not good for delegation** (keep in Claude Code):
- Tasks requiring deep codebase understanding across many files
- Architectural decisions
- Tasks needing interactive user feedback
- Code review (use interpeer instead)

### 2. Prepare Prompts

For each task, craft a detailed prompt that includes:
- The specific problem or task
- Relevant file paths
- Expected outcome (tests pass, builds clean, etc.)
- Any constraints or patterns to follow
- The project's CLAUDE.md or AGENTS.md content if the working directory has one

### 3. Dispatch

Launch each Codex agent using the dispatch script:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  -C /path/to/project \
  -o /tmp/codex-output-TASKID.md \
  -s workspace-write \
  "Your detailed prompt here"
```

**Important flags:**
- `-C <dir>`: Working directory (REQUIRED — set to the project root)
- `-o <file>`: Output file for the agent's last message (REQUIRED)
- `-s <mode>`: Sandbox mode. Use `workspace-write` for most tasks, `danger-full-access` only when the task needs system-wide access

Launch multiple agents in parallel using `run_in_background: true` on each Bash call.

### 4. Monitor

Check agent progress by tailing output files:

```bash
tail -c 2000 /tmp/codex-output-TASKID.md
```

Codex sessions are also stored at `~/.codex/sessions/YYYY/MM/DD/` as JSONL files if you need the full transcript.

### 5. Review Results

After agents complete:
1. **Read output files** to understand what each agent did
2. **Check compilation**: `go build ./...` or equivalent
3. **Run tests**: `go test ./...` or equivalent
4. **Review diffs**: `git diff` to see actual changes
5. **Assess quality**: Look for over-engineering, missing edge cases, cosmetic-only changes

### 6. Report

Summarize results to the user:
- What each agent accomplished
- Which tasks succeeded vs. had issues
- Any concerns about code quality
- Verification results (build + test output)

### 7. Close Out

If using beads (`bd`), close completed beads:
```bash
bd close <bead-id1> <bead-id2> ... --reason="Fixed by Codex agent, reviewed by Claude"
```

## Tips

- **Prompt quality matters most**: A vague prompt produces vague results. Include file paths, function names, and concrete acceptance criteria.
- **One task per agent**: Don't ask a single agent to fix 3 bugs. Dispatch 3 agents.
- **Set GOCACHE**: For Go projects, add `GOCACHE=/tmp/go-build-cache` to the prompt's instructions if the default cache path has permission issues.
- **Verify independently**: Never trust an agent's self-reported success. Always run builds and tests yourself.
- **Review cosmetic changes**: Codex agents sometimes reformat code or adjust alignment. Flag these separately from functional changes.
