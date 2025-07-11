#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(dirname -- "$(dirname -- "${BASH_SOURCE[0]}")")"

JUSTFILE=$(find "$PWD" -maxdepth 1 -type f -name "[Jj]ustfile" | head -n1)
if [[ -z "$JUSTFILE" ]]; then
  echo "Creating '$PWD/justfile'"
  cat <<EOF >justfile
import '$ROOT_DIR/pick.just'

_default:
    just --list
EOF
else
  echo "Updating '$JUSTFILE'"
  TMPFILE=$(mktemp)
  echo "import '$ROOT_DIR/pick.just'" >"$TMPFILE"
  cat "$JUSTFILE" >>"$TMPFILE"
  mv "$TMPFILE" "$JUSTFILE"
fi

just pick
