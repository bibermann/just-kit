#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"

"$ROOT_DIR/bash/setup.sh"
"$ROOT_DIR/pick/setup.sh"
