# Interclode

> See `AGENTS.md` for full development guide.

## Overview

Claude Code plugin for cross-AI delegation — dispatch Codex CLI agents for parallel autonomous work, then review and verify results.

## Status

v0.2.1 — Published via `interclode@interagency-marketplace`

## Quick Commands

```bash
# Install plugin
claude plugin install interclode@interagency-marketplace

# Test dispatch (dry run)
bash scripts/dispatch.sh --dry-run --inject-docs -C /tmp -o /tmp/test.md "Hello"

# Show dispatch help
bash scripts/dispatch.sh --help
```

## Design Decisions (Do Not Re-Ask)

- Codex reads AGENTS.md natively from `-C` directory, so `--inject-docs` defaults to CLAUDE.md only
- `dispatch.sh` is a thin wrapper around `codex exec` — keep it simple, don't duplicate Codex features
- Prompt quality is the primary lever for agent success — the plugin focuses on prompt structure, not orchestration complexity
- `require_arg()` pattern for all flag parsing under `set -euo pipefail`
- Known Codex flags are explicitly listed for passthrough (not auto-detected) to prevent value-eating bugs
