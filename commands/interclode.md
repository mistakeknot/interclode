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

### 0. Fetch Codex CLI Docs

**First**, fetch the current Codex CLI reference to ensure you have the latest flags:

```
WebFetch: https://developers.openai.com/codex/cli/reference/
Prompt: "Extract all command line options, flags, their types, defaults, and subcommands for codex exec. Include global flags that apply to all subcommands."
```

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

Use `--inject-docs` to auto-prepend the project's CLAUDE.md to the prompt (Codex already reads AGENTS.md natively from the `-C` directory):

**Resolve dispatch.sh path first** — `$CLAUDE_PLUGIN_ROOT` is NOT available in the Bash environment:
```bash
DISPATCH=$(find ~/.claude/plugins/cache -path '*/interclode/*/scripts/dispatch.sh' 2>/dev/null | head -1)
[ -z "$DISPATCH" ] && DISPATCH=$(find ~/projects/interclode -name dispatch.sh -path '*/scripts/*' 2>/dev/null | head -1)
```

```bash
bash $DISPATCH \
  --inject-docs -C /path/to/project \
  --name taskname -o /tmp/interclode-{name}.md \
  -s workspace-write \
  "Your task-specific prompt here"
```

### 4. Dispatch

Launch each Codex agent using the dispatch script:

```bash
bash $DISPATCH \
  --inject-docs -C /path/to/project \
  --name fix-bug -o /tmp/interclode-{name}.md \
  -s workspace-write \
  "Your detailed prompt here"
```

**Dispatch script flags:**
- `-C <dir>`: Working directory (REQUIRED — set to the project root)
- `-o <file>`: Output file for the agent's last message (REQUIRED; supports `{name}` template)
- `-s <mode>`: Sandbox mode. Use `workspace-write` for most tasks, `danger-full-access` only when needed
- `-i <file>`: Attach image to prompt (repeatable, for multimodal tasks)
- `--inject-docs[=SCOPE]`: Prepend CLAUDE.md from working dir to prompt (default). Use `=agents` or `=all` to include AGENTS.md (usually redundant — Codex reads it natively)
- `--name <label>`: Label for `{name}` substitution in output path
- `--prompt-file <file>`: Read prompt from file instead of positional arg (avoids shell escaping)
- `--dry-run`: Print the constructed command without executing (for debugging prompts)
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

If an agent failed, either resume (`codex exec resume --last "fix X"`) or re-dispatch with tighter constraints. See the delegate skill for detailed retry guidance.

### 7. Report and Close

Summarize results to the user:
- What each agent accomplished
- Which tasks succeeded vs. had issues
- Verification results (build + test output)
- Suggested commit message with Co-Authored-By lines

If using beads (`bd`), close completed beads:
```bash
bd close <bead-id1> <bead-id2> ... --reason="Fixed by Codex agent, reviewed by Claude"
```

## Tips

- **Prompt quality matters most**: A vague prompt produces vague results. Include file paths, function names, and concrete acceptance criteria.
- **One task per agent**: Don't ask a single agent to fix 3 bugs. Dispatch 3 agents.
- **Use --inject-docs**: Injects CLAUDE.md into the prompt so Codex gets Claude Code-specific project conventions.
- **Use --name**: Makes output files self-documenting (`interclode-fix-auth.md` vs `codex-output-1.md`).
- **Use --dry-run**: Preview the full command and prompt before executing, especially useful when `--inject-docs` is on.
- **Use --prompt-file**: For long, multi-paragraph prompts — avoids shell quoting pain.
- **Use --add-dir**: For monorepo tasks that need to write to directories outside `-C` (passed through to codex exec).
- **Set GOCACHE**: For Go projects, add `GOCACHE=/tmp/go-build-cache` to the prompt's instructions if the default cache path has permission issues.
- **Verify independently**: Never trust an agent's self-reported success. Always run builds and tests yourself.
- **Resume failed agents**: Use `codex exec resume --last "fix X"` to continue where a failed agent left off.
- **Review cosmetic changes**: Codex agents sometimes reformat code or adjust alignment. Flag these separately from functional changes.
