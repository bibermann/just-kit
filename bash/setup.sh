#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(dirname -- "$(dirname -- "${BASH_SOURCE[0]}")")"

if [[ ! -f just-bash ]]; then
  ln -s "$ROOT_DIR/bash/just-bash" just-bash
fi

echo 'Hint: You need to run `source just-bash` in every new shell to profit'
