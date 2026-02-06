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
- Single background tasks you want to fire-and-forget while continuing other work

**Not good for delegation** (keep in Claude Code):
- Tasks requiring deep codebase understanding across many files
- Architectural decisions
- Tasks needing interactive user feedback
- Code review (use interpeer instead)

### 2. Check for File Overlap

Before dispatching multiple agents, verify no two tasks will touch the same files. If they do, combine into one agent or dispatch sequentially.

### 3. Prepare Prompts

For each task, craft a detailed prompt that includes:
- The specific problem or task
- Relevant file paths
- Expected outcome (tests pass, builds clean, etc.)
- The standard constraints (see delegate skill)

Use `--inject-docs` to auto-prepend the project's CLAUDE.md/AGENTS.md to the prompt:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name taskname -o /tmp/interclode-{name}.md \
  -s workspace-write \
  "Your task-specific prompt here"
```

### 4. Dispatch

Launch each Codex agent using the dispatch script:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name fix-bug -o /tmp/interclode-{name}.md \
  -s workspace-write \
  "Your detailed prompt here"
```

**Dispatch script flags:**
- `-C <dir>`: Working directory (REQUIRED — set to the project root)
- `-o <file>`: Output file for the agent's last message (REQUIRED; supports `{name}` template)
- `-s <mode>`: Sandbox mode. Use `workspace-write` for most tasks, `danger-full-access` only when needed
- `--inject-docs`: Auto-prepend CLAUDE.md/AGENTS.md from working dir to prompt
- `--name <label>`: Label for `{name}` substitution in output path
- `--help`: Show all options

Launch multiple agents in parallel using `run_in_background: true` on each Bash call.

### 5. Monitor

Check agent progress by tailing output files:

```bash
tail -c 2000 /tmp/interclode-fix-bug.md
```

Codex sessions are also stored at `~/.codex/sessions/YYYY/MM/DD/` as JSONL files if you need the full transcript.

### 6. Verify Results

After agents complete, run the full verification checklist from the delegate skill:
1. Read output file
2. Check compilation
3. Run tests
4. Review diffs
5. Check diff size is proportional to task scope
6. Investigate suspiciously large diffs

### 7. Report

Summarize results to the user:
- What each agent accomplished
- Which tasks succeeded vs. had issues
- Verification results (build + test output)
- Suggested commit message with Co-Authored-By lines

### 8. Close Out

If using beads (`bd`), close completed beads:
```bash
bd close <bead-id1> <bead-id2> ... --reason="Fixed by Codex agent, reviewed by Claude"
```

## Tips

- **Prompt quality matters most**: A vague prompt produces vague results. Include file paths, function names, and concrete acceptance criteria.
- **One task per agent**: Don't ask a single agent to fix 3 bugs. Dispatch 3 agents.
- **Use --inject-docs**: Eliminates manual context boilerplate and ensures agents get the project's conventions.
- **Use --name**: Makes output files self-documenting (`interclode-fix-auth.md` vs `codex-output-1.md`).
- **Set GOCACHE**: For Go projects, add `GOCACHE=/tmp/go-build-cache` to the prompt's instructions if the default cache path has permission issues.
- **Verify independently**: Never trust an agent's self-reported success. Always run builds and tests yourself.
- **Review cosmetic changes**: Codex agents sometimes reformat code or adjust alignment. Flag these separately from functional changes.
