# Interclode

Cross-AI delegation plugin for Claude Code. Dispatch [Codex CLI](https://github.com/openai/codex) agents to work on tasks in parallel, then review and verify their results.

Claude Code acts as orchestrator. Codex agents do the work. You verify.

## Installation

```bash
claude plugin install interclode@interagency-marketplace
```

## Usage

Invoke from Claude Code:

```
/interclode Fix the race condition in arbiter.go and add tests for the signal broker
```

Or use the dispatch script directly:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/dispatch.sh \
  --inject-docs -C /path/to/project \
  --name fix-race -o /tmp/interclode-{name}.md \
  "Fix the race condition in arbiter.go"
```

## Dispatch Script Flags

| Flag | Description |
|------|-------------|
| `-C <dir>` | Working directory (required) |
| `-o <file>` | Output file (`{name}` replaced by `--name` value) |
| `--inject-docs[=SCOPE]` | Prepend CLAUDE.md to prompt (default). `=agents` or `=all` for AGENTS.md too |
| `--name <label>` | Label for `{name}` substitution in output path |
| `--prompt-file <file>` | Read prompt from file instead of positional arg |
| `-i <file>` | Attach image to prompt (repeatable) |
| `--dry-run` | Preview command without executing |
| `-s <mode>` | Sandbox: `workspace-write` (default), `read-only`, `danger-full-access` |
| `-m <model>` | Override model |

## How It Works

1. **Analyze** — Identify discrete, well-scoped tasks
2. **Check overlap** — Ensure no two agents touch the same files
3. **Craft prompts** — Include file paths, success criteria, and constraints
4. **Dispatch** — Launch Codex agents as parallel Bash tool calls in a single message
5. **Verify** — Build, test, review diff when all agents return
6. **Verify** — Build, test, review diff, check proportionality
7. **Report** — Summarize results with evidence

## Requirements

- [Codex CLI](https://github.com/openai/codex) installed and configured (`~/.codex/config.toml`)
- Claude Code with plugin support

## License

MIT
