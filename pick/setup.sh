#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(dirname -- "$(dirname -- "${BASH_SOURCE[0]}")")"

if [[ "${1-}" == "--no-defaults" ]]; then
  DEFAULT_IMPORTS=""
else
  DEFAULT_IMPORTS=$("$ROOT_DIR/pick/get-default-imports.sh" "$@")
fi

JUSTFILE=$(find "$PWD" -maxdepth 1 -type f -name "[Jj]ustfile" -o -name "\.[Jj]ustfile" | head -n1)
if [[ -z "$JUSTFILE" ]]; then
  echo "Creating '$PWD/justfile'"
  echo "$DEFAULT_IMPORTS" >justfile
  cat <<EOF >>justfile
import '$ROOT_DIR/pick.just'

_default:
    just --list
    @just _just_bash_hint
EOF
else
  echo "Updating '$JUSTFILE'"
  TMPFILE=$(mktemp)
  echo "$DEFAULT_IMPORTS" >"$TMPFILE"
  echo "import '$ROOT_DIR/pick.just'" >>"$TMPFILE"
  cat "$JUSTFILE" >>"$TMPFILE"
  mv "$TMPFILE" "$JUSTFILE"
fi

just pick
