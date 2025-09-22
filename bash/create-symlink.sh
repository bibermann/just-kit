#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(dirname -- "$(dirname -- "${BASH_SOURCE[0]}")")"

if [[ ! -f just-bash ]]; then
  ln -s "$ROOT_DIR/bash/just-bash" just-bash
fi
