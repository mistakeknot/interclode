#!/usr/bin/env bash
# Interclode dispatch script — wraps codex exec with sensible defaults
#
# Usage:
#   bash dispatch.sh -C /path/to/project -o /tmp/output.md "prompt"
#   bash dispatch.sh -C /path --inject-docs --name vet -o /tmp/interclode-{name}.md "prompt"
#
# Flags:
#   -C, --cd <DIR>           Working directory for codex exec
#   -o, --output-last-message <FILE>  Save agent's final message (supports {name} template)
#   -s, --sandbox <MODE>     Sandbox mode (default: workspace-write)
#   -m, --model <MODEL>      Override model
#   --inject-docs            Prepend CLAUDE.md and/or AGENTS.md from -C dir to prompt
#   --name <LABEL>           Label for {name} substitution in output path
#   --help                   Show this help message

set -euo pipefail

# Defaults
SANDBOX="workspace-write"
WORKDIR=""
OUTPUT=""
MODEL=""
INJECT_DOCS=false
NAME=""
EXTRA_ARGS=()

show_help() {
  cat <<'HELP'
interclode dispatch — wraps codex exec with sensible defaults

Usage:
  dispatch.sh [OPTIONS] "prompt"

Options:
  -C, --cd <DIR>                Working directory (required for --inject-docs)
  -o, --output-last-message <FILE>  Output file ({name} replaced by --name value)
  -s, --sandbox <MODE>          Sandbox: read-only | workspace-write | danger-full-access
  -m, --model <MODEL>           Override model (default: from ~/.codex/config.toml)
  --inject-docs                 Prepend CLAUDE.md/AGENTS.md from working dir to prompt
  --name <LABEL>                Label for {name} in output path and tracking
  --help                        Show this help

Examples:
  dispatch.sh -C /root/projects/Autarch -o /tmp/out.md "Fix the bug in foo.go"
  dispatch.sh -C /root/projects/Autarch --inject-docs -o /tmp/interclode-{name}.md --name vet "Vet the signals package"
HELP
  exit 0
}

# Parse arguments
while [[ $# -gt 1 ]]; do
  case "$1" in
    --help|-h)
      show_help
      ;;
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
    --inject-docs)
      INJECT_DOCS=true
      shift
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

# Handle --help as last/only argument
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_help
fi

# Last argument is the prompt
PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided" >&2
  echo "Usage: dispatch.sh -C <dir> -o <output> [--inject-docs] [--name <label>] \"prompt\"" >&2
  echo "       dispatch.sh --help for more options" >&2
  exit 1
fi

# Apply --name substitution to output path
if [[ -n "$NAME" && -n "$OUTPUT" ]]; then
  OUTPUT="${OUTPUT//\{name\}/$NAME}"
fi

# Inject docs from working directory into prompt
if [[ "$INJECT_DOCS" == true ]]; then
  if [[ -z "$WORKDIR" ]]; then
    echo "Error: --inject-docs requires -C <dir>" >&2
    exit 1
  fi

  DOCS_PREFIX=""

  if [[ -f "$WORKDIR/CLAUDE.md" ]]; then
    DOCS_PREFIX+="$(cat "$WORKDIR/CLAUDE.md")"
    DOCS_PREFIX+=$'\n\n'
  fi

  if [[ -f "$WORKDIR/AGENTS.md" ]]; then
    DOCS_PREFIX+="$(cat "$WORKDIR/AGENTS.md")"
    DOCS_PREFIX+=$'\n\n'
  fi

  if [[ -n "$DOCS_PREFIX" ]]; then
    PROMPT="${DOCS_PREFIX}---

${PROMPT}"
  fi
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

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  CMD+=("${EXTRA_ARGS[@]}")
fi

CMD+=("$PROMPT")

# Execute
exec "${CMD[@]}"
