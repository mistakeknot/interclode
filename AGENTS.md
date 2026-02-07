# Interclode — Development Guide

Cross-AI delegation plugin for [Claude Code](https://claude.com/claude-code). Dispatches [Codex CLI](https://github.com/openai/codex) agents to work on tasks in parallel, then reviews and verifies their results.

## Project Status

- **Version**: 0.2.2
- **Distribution**: `interclode@interagency-marketplace`
- **Source**: GitHub `mistakeknot/interclode`
- **License**: MIT

## Architecture

```
interclode/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (name, version, description)
├── commands/
│   └── interclode.md        # /interclode slash command definition
├── scripts/
│   └── dispatch.sh          # Core wrapper around `codex exec`
├── skills/
│   └── delegate/
│       └── SKILL.md         # Delegation protocol (Steps 0–7 + 6b retry)
├── CLAUDE.md                # Quick reference (auto-loaded by Claude Code)
├── AGENTS.md                # This file (read natively by Codex CLI)
└── README.md                # GitHub landing page
```

### Component Roles

| Component | Purpose |
|-----------|---------|
| `dispatch.sh` | Bash wrapper that adds `--inject-docs`, `--name`, `--dry-run`, `--prompt-file` on top of `codex exec` |
| `SKILL.md` | The delegation protocol: task identification, prompt crafting, dispatch, monitoring, verification |
| `interclode.md` | Slash command entry point — triggers the delegation workflow |
| `plugin.json` | Plugin metadata for Claude Code's plugin system |

### Data Flow

```
User invokes /interclode
  → Claude Code loads SKILL.md (delegation protocol)
  → Claude crafts prompts following the template
  → dispatch.sh wraps each prompt with context injection
  → codex exec runs each agent in background
  → Agent reads AGENTS.md from -C dir (native)
  → Agent reads CLAUDE.md if --inject-docs was used
  → Agent writes output to -o file
  → Claude polls output, verifies, reports
```

## Development Setup

No build step — this is a pure Claude Code plugin (markdown + bash).

```bash
# Clone
git clone git@github.com:mistakeknot/interclode.git
cd interclode

# Test dispatch.sh locally
bash scripts/dispatch.sh --help
bash scripts/dispatch.sh --dry-run -C /tmp -o /tmp/test.md "test prompt"
```

### Plugin Installation (for testing)

```bash
# Update marketplace cache
claude plugin marketplace update interagency-marketplace

# Install from marketplace
claude plugin install interclode@interagency-marketplace
```

After installing, `/interclode` becomes available in Claude Code sessions.

## dispatch.sh Reference

### Synopsis

```bash
dispatch.sh [OPTIONS] "prompt"
dispatch.sh [OPTIONS] --prompt-file <file>
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `-C, --cd <DIR>` | (none) | Working directory for Codex agent (required) |
| `-o, --output-last-message <FILE>` | (none) | Output file; `{name}` is replaced by `--name` value |
| `-s, --sandbox <MODE>` | `workspace-write` | `read-only`, `workspace-write`, or `danger-full-access` |
| `-m, --model <MODEL>` | config.toml default | Override Codex model |
| `-i, --image <FILE>` | (none) | Attach image (repeatable) |
| `--inject-docs[=SCOPE]` | off | Prepend docs to prompt. Bare/`=claude`: CLAUDE.md only. `=agents`: AGENTS.md only. `=all`: both |
| `--name <LABEL>` | (none) | Label for `{name}` in output path |
| `--prompt-file <FILE>` | (none) | Read prompt from file (mutually exclusive with positional prompt) |
| `--dry-run` | off | Print command without executing |
| `--` | — | End of options (next arg is prompt even if it starts with `-`) |

### Codex Flag Passthrough

Known Codex flags are explicitly handled to prevent the arg parser from misinterpreting their values:

**Value flags** (consume next arg): `--add-dir`, `--output-schema`, `-p`/`--profile`, `-c`/`--config`, `--color`, `-a`/`--ask-for-approval`, `--enable`, `--disable`, `--local-provider`

**Boolean flags** (no value): `--json`, `--full-auto`, `--skip-git-repo-check`, `--oss`, `--dangerously-bypass-approvals-and-sandbox`, `--yolo`, `--search`, `--no-alt-screen`

Unknown `-*` flags are passed through as boolean (no value consumed). If you need to pass an unknown flag with a value, use `--` to separate it from dispatch.sh's parser.

### Context Injection (`--inject-docs`)

The `--inject-docs` flag prepends project documentation to the prompt before sending it to Codex:

- **Default (bare `--inject-docs`)**: Prepends only CLAUDE.md — this is the recommended setting because Codex CLI reads AGENTS.md natively from the `-C` directory
- **`=agents`**: Prepends only AGENTS.md (usually redundant)
- **`=all`**: Prepends both CLAUDE.md and AGENTS.md

A warning is printed if the injected content exceeds 20KB. If no doc files are found, a note is printed.

### Edge Cases and Limitations

| Scenario | Behavior |
|----------|----------|
| Missing flag value (`-C` with no dir) | Error: "requires a value" |
| `--prompt-file` + positional prompt | Error: cannot use both |
| Empty prompt file | Error: "Prompt file is empty" |
| `{name}` in `-o` without `--name` | Warning printed, literal `{name}` left in path |
| Prompt > ~150KB | May hit kernel ARG_MAX limit (~2MB total including env vars) |
| Paths with spaces | Handled correctly (bash arrays preserve quoting) |
| Prompt with special chars (`$`, `` ` ``, `"`) | Handled correctly (prompt is a bash variable, not eval'd) |

## Delegation Protocol

The SKILL.md defines an 8-step workflow:

0. **Fetch Codex CLI Docs** — WebFetch the official CLI reference for latest flags and capabilities
1. **Identify Tasks** — Analyze work, propose task decomposition to user
2. **Check File Overlap** — Ensure no two agents write the same file
3. **Craft Prompts** — Use the standard template with mandatory constraints
4. **Dispatch** — Launch agents as parallel Bash tool calls in a single message (timeout: 600000)
5. **Verify** — All agents return together; build, test, diff review for each
6. **Verify** — Build, test, diff review, proportionality check for EACH agent
7. **Report** — Summarize results with evidence, suggest commit message

### Standard Prompt Constraints

Every prompt MUST include these constraints:

```
- Only modify files listed in "Relevant Files" unless absolutely necessary
- Do not reformat, realign, or adjust whitespace in code you didn't functionally change
- Do not add comments, docstrings, or type annotations to unchanged code
- Do not refactor or rename anything not directly related to the task
- Keep the fix minimal — prefer 5 clean lines over 50 "proper" lines
- If GOCACHE permission errors occur, use: GOCACHE=/tmp/go-build-cache
```

### Verification Checklist

For EACH completed agent, run ALL of these:

```bash
cat /tmp/interclode-{name}.md                    # 1. Read output
go build ./relevant/package/...                   # 2. Check build
go test ./relevant/package/... -v                 # 3. Run tests
git diff -- relevant/files                        # 4. Review diff
git diff --stat                                   # 5. Check proportionality
```

### Retry Strategy

| Situation | Action |
|-----------|--------|
| Agent was on right track but hit build/test error | Resume: `codex exec resume --last "fix X"` |
| Agent over-engineered or went wrong direction | Re-dispatch with tighter constraints |
| Agent touched wrong files | Re-dispatch with explicit file list + "only modify listed files" |

## Codex CLI Quick Reference

```bash
# Basic execution
codex exec -s workspace-write -C <dir> -o <output> "prompt"

# Resume failed session
codex exec resume --last "follow-up prompt"
codex exec resume <SESSION_ID> "follow-up prompt"

# Code review
codex exec review --uncommitted "focus on error handling"

# Configuration
~/.codex/config.toml    # model, approval_policy, sandbox_mode
~/.codex/sessions/      # Session transcripts (YYYY/MM/DD/*.jsonl)
```

## Codex-First Mode

Codex-first mode is a session-level behavioral contract where Claude delegates **all code changes** to Codex agents, restricting itself to reading, planning, orchestrating, and verifying.

### Activation

1. **CLAUDE.md directive** (persistent, per-project):
   ```markdown
   ## Execution Mode
   codex-first: true
   ```
   Claude reads this at session start and enters codex-first mode automatically.

2. **Slash command** (session toggle):
   `/clavain:clodex` (or `/clavain:codex-first`) — toggles the mode on/off, overriding the CLAUDE.md default.

### How It Integrates with Interclode

In codex-first mode, Claude uses two dispatch paths:

| Path | When | Skill |
|------|------|-------|
| **Single-task dispatch** | One edit at a time (most common) | `clavain:codex-first-dispatch` |
| **Multi-task parallel dispatch** | Executing a plan with 3+ independent tasks | `clavain:codex-delegation` -> `interclode:delegate` |

Both paths use interclode's `dispatch.sh` as the underlying transport. The `codex-first-dispatch` skill is a lighter wrapper that skips multi-task planning and file overlap checks.

### Behavioral Contract

When codex-first is active, Claude:
- **Never** uses Edit/Write/NotebookEdit on source code
- **Always** reads freely (Read, Grep, Glob)
- **Always** dispatches code changes through Codex agents
- **Always** verifies (build, test, diff) before reporting success
- **Always** handles git operations (add, commit, push) directly
- **May** edit non-code files (docs, config, markdown) directly

### Dispatch Flow

```
Claude: Read code -> Plan change -> Write prompt file -> Dispatch via dispatch.sh
Codex:  Read AGENTS.md -> Implement change -> Report
Claude: Read output -> Build -> Test -> Diff review -> Commit
```

## Code Conventions

- **Bash strict mode**: `set -euo pipefail` in dispatch.sh
- **`require_arg()` pattern**: All flags that take values validate their argument exists before accessing it (prevents `$2: unbound variable` under `set -u`)
- **Explicit flag lists**: Known Codex flags are listed explicitly rather than auto-detected, to prevent the arg parser from eating a flag's value as the positional prompt
- **Error messages to stderr**: All errors, warnings, and notes go to `>&2`; only `--dry-run` output and `exec` go to stdout
- **No dependencies**: Pure bash, no external tools beyond Codex CLI itself

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `codex: command not found` | Install Codex CLI: `npm install -g @openai/codex` |
| GOCACHE permission denied | Add `GOCACHE=/tmp/go-build-cache` to the prompt |
| Agent self-reports success but tests fail | Always run verification independently |
| Agent reformats unrelated code | Add "do not reformat unchanged code" to constraints |
| Agent over-engineers | Add "keep it minimal" + "prefer N lines over M lines" |
| Agent touches files outside scope | List files explicitly in "Relevant Files" section |
| Output file empty | Check `~/.codex/sessions/YYYY/MM/DD/` for JSONL transcript |
| `--add-dir` value treated as prompt | Use explicit flag: `--add-dir /path` (it's in the passthrough list) |
| Prompt > 150KB fails | Use `--prompt-file` and reduce prompt size, or split into multiple agents |

## Known Issues

- **ARG_MAX limit**: Very large prompts (>150KB) combined with large environment variables can exceed the kernel's ~2MB `execve()` limit. Use `--prompt-file` to keep the command line small, but the prompt content still needs to fit.
- **No built-in parallelism**: dispatch.sh launches one agent per invocation. Parallelism is achieved by the caller issuing multiple Bash tool calls in a single message.
- **Session transcript format**: Codex JSONL lines are 10-100KB each. Use `tail -c` (byte-based) not `tail -n` (line-based) when checking output.

## Release Process

```bash
# 1. Update version in plugin.json
# 2. Commit and push
git add -A && git commit -m "feat: v0.X.Y — description" && git push

# 3. Update marketplace
claude plugin marketplace update interagency-marketplace

# 4. Reinstall
claude plugin install interclode@interagency-marketplace
```
