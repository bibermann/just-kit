#!/usr/bin/env bash
set -euo pipefail

exists_in_array() {
  # Check if an item exists in an array
  # Usage: exists_in_array "item" "${array[@]}"
  # Returns: 0 if found, 1 if not found
  local item="$1"
  shift
  local array=("$@")
  for element in "${array[@]}"; do
    [[ "$element" == "$item" ]] && return 0
  done
  return 1
}

real_paths=()
search_patterns=()
search_justfiles() {
  local pattern="$1"
  local dir="$2"
  local prefix="$3"
  shift 3
  local extra_find_args=("$@")

  if exists_in_array "$pattern" "${search_patterns[@]}"; then
    echo >&2 "Skipping $pattern (already searched)"
    return
  else
    search_patterns+=("$pattern")
  fi

  echo >&2 -n "Searching $pattern: "
  count_unique=0
  count_duplicates=0
  if [ -d "$dir" ]; then
    while IFS= read -r path; do
      # Check if this path is already in our paths array
      is_duplicate=false
      for existing_path in "${real_paths[@]}"; do
        if [ "$existing_path" = "${dir%%/}/$path" ]; then
          is_duplicate=true
          break
        fi
      done

      if [ "$is_duplicate" = false ]; then
        echo "$prefix$path"
        real_paths+=("${dir%%/}/$path")
        ((count_unique += 1))
      else
        ((count_duplicates += 1))
      fi
    done < <(find "$dir" "${extra_find_args[@]}" -name "*.just" -type f -printf "%P\n" | sort)
  fi
  echo >&2 -n "$count_unique found"
  if [[ $count_duplicates -gt 0 ]]; then
    echo >&2 -n " (+$count_duplicates duplicates)"
  fi
  echo >&2
}

# Search *.just files in $PWD
CURRENT_DIR="$PWD"
CURRENT_PREFIX=""
while :; do
  if [[ "${CURRENT_DIR%%/}" =~ /\.just($|/) ]]; then
    search_justfiles "${CURRENT_DIR%%/}/**.just" "$CURRENT_DIR" "$CURRENT_PREFIX"
  else
    search_justfiles "${CURRENT_DIR%%/}/*.just" "$CURRENT_DIR" "$CURRENT_PREFIX" -maxdepth 1
    search_justfiles "${CURRENT_DIR%%/}/.just/**.just" "${CURRENT_DIR%%/}/.just" "$CURRENT_PREFIX.just/"
  fi

  if [ "$CURRENT_DIR" = "/" ]; then
    break
  fi
  CURRENT_DIR=$(dirname "$CURRENT_DIR")
  if [ "$CURRENT_DIR" = "$HOME" ]; then
    CURRENT_PREFIX='~/'
  elif [[ "$CURRENT_DIR" != "$HOME"* ]]; then
    CURRENT_PREFIX="$CURRENT_DIR"
  else
    CURRENT_PREFIX="../$CURRENT_PREFIX"
  fi
done

# Search *.just files in $EXTRA_JUST_ROOTS
if [ -n "${EXTRA_JUST_ROOTS:-}" ]; then
  IFS=':' read -ra EXTRA_DIRS <<<"$EXTRA_JUST_ROOTS"
  for EXTRA_DIR in "${EXTRA_DIRS[@]}"; do
    if ! [ -d "$EXTRA_DIR" ]; then
      echo >&2 "Warning: $EXTRA_DIR in \$EXTRA_JUST_ROOTS is not a directory."
      continue
    fi
    CURRENT_DIR="${EXTRA_DIR%%/}/"
    CURRENT_PREFIX="${CURRENT_DIR/#$HOME\//\~\/}"

    search_justfiles "$CURRENT_DIR**.just" "$CURRENT_DIR" "$CURRENT_PREFIX"

    if [ "$CURRENT_DIR" = "/" ]; then
      continue
    fi

    CURRENT_DIR=$(dirname "$CURRENT_DIR")
    CURRENT_DIR="${CURRENT_DIR%%/}/"
    CURRENT_PREFIX="${CURRENT_DIR/#$HOME\//\~\/}"

    while :; do
      search_justfiles "$CURRENT_DIR*.just" "$CURRENT_DIR" "$CURRENT_PREFIX" -maxdepth 1
      search_justfiles "$CURRENT_DIR.just/**.just" "$CURRENT_DIR.just" "$CURRENT_PREFIX.just/"

      if [ "$CURRENT_DIR" = "/" ]; then
        break
      fi

      CURRENT_DIR=$(dirname "$CURRENT_DIR")
      CURRENT_DIR="${CURRENT_DIR%%/}/"
      CURRENT_PREFIX="${CURRENT_DIR/#$HOME\//\~\/}"
    done
  done
fi
