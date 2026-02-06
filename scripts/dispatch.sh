#!/usr/bin/env bash
# Interclode dispatch script — wraps codex exec with sensible defaults
#
# Usage:
#   bash dispatch.sh -C /path/to/project -o /tmp/output.md -s workspace-write "prompt"
#   bash dispatch.sh -C /path/to/project -o /tmp/output.md "prompt"  # defaults to workspace-write
#
# All arguments before the final positional argument are passed through to codex exec.
# The final positional argument is the prompt.

set -euo pipefail

# Defaults
SANDBOX="workspace-write"
WORKDIR=""
OUTPUT=""
MODEL=""
EXTRA_ARGS=()

# Parse arguments
while [[ $# -gt 1 ]]; do
  case "$1" in
    -C|--cd)
      WORKDIR="$2"
      shift 2
      ;;
    -o|--output-last-message)
      OUTPUT="$2"
      shift 2
      ;;
    -s|--sandbox)
      SANDBOX="$2"
      shift 2
      ;;
    -m|--model)
      MODEL="$2"
      shift 2
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

# Last argument is the prompt
PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided" >&2
  echo "Usage: dispatch.sh -C <dir> -o <output> [-s <sandbox>] [-m <model>] \"prompt\"" >&2
  exit 1
fi

# Build codex exec command
CMD=(codex exec)
CMD+=(-s "$SANDBOX")

if [[ -n "$WORKDIR" ]]; then
  CMD+=(-C "$WORKDIR")
fi

if [[ -n "$OUTPUT" ]]; then
  CMD+=(-o "$OUTPUT")
fi

if [[ -n "$MODEL" ]]; then
  CMD+=(-m "$MODEL")
fi

CMD+=("${EXTRA_ARGS[@]}")
CMD+=("$PROMPT")

# Execute
exec "${CMD[@]}"
