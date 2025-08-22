#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(dirname -- "$(dirname -- "${BASH_SOURCE[0]}")")"

default_just_files_filename='default-just-files.txt'

if ! [[ -f "$default_just_files_filename" ]]; then
  exit 0
fi

IGNORE_MISSING_REPOS="false"
IGNORE_MISSING_FILES="false"
while [[ $# -gt 0 ]]; do
  case $1 in
  --ignore-missing-repos)
    IGNORE_MISSING_REPOS="true"
    shift
    ;;
  --ignore-missing-files)
    IGNORE_MISSING_FILES="true"
    shift
    ;;
  *)
    echo >&2 "Unsupported argument: $1"
    exit 1
    ;;
  esac
done

get_subpath() {
  echo "${1#${2%/}/}"
}

declare -A repo_to_git_root
declare -A repo_path_to_path

mapfile -t paths < <("$ROOT_DIR/pick/search-just-files.sh")
for path in "${paths[@]}"; do
  GIT_ROOT="$(git -C "$(dirname -- "${path/\~/$HOME}")" rev-parse --show-toplevel)"
  repo="$("$ROOT_DIR/pick/get-git-remote.sh" "$GIT_ROOT")"
  repo_path="$(get_subpath "$(realpath "${path/\~/$HOME}")" "$GIT_ROOT")"

  repo_to_git_root["$repo"]="$GIT_ROOT"
  repo_path_to_path["$repo:$repo_path"]="$path"
done

# Extract all repos and repo:repo_path entries from default-just-files.txt and check if they exist
missing_repos=()
missing_files=()
while IFS= read -r line; do
  # Skip empty lines
  [[ -n "$line" ]] || continue

  # Extract all repo:repo_path patterns from the line (before and after # overrides)
  repo_paths=($(echo "$line" | grep -oE '[^[:space:]#,]+:[^[:space:],]+' || true))

  for repo_path in "${repo_paths[@]}"; do
    repo="${repo_path%:*}"
    path_after_repo="${repo_path##*:}"
    if [[ ! -v repo_to_git_root["$repo"] ]]; then
      if [[ ! " ${missing_repos[*]} " =~ " ${repo} " ]]; then
        missing_repos+=("$repo")
        continue
      fi
    fi
    if [[ ! -v repo_path_to_path["$repo_path"] ]]; then
      if [[ ! " ${missing_files[*]} " =~ " ${repo_path} " ]]; then
        missing_files+=("${repo_to_git_root["$repo"]}/$path_after_repo")
      fi
    fi
  done
done <"$default_just_files_filename"

print_mitigation_help() {
  echo >&2
  echo >&2 "You may run this again with '$1' to ignore them"
  echo >&2 "or run this again with '--no-defaults' to completely ignore '$default_just_files_filename'."
  echo >&2 "See https://github.com/bibermann/just-kit/blob/main/README.md for more information."
}

# Report missing repos
if [[ ${#missing_repos[@]} -gt 0 ]]; then
  if [[ "$IGNORE_MISSING_REPOS" != "true" ]]; then
    echo >&2
    echo >&2 "Error: Missing repositories:"
    printf -- '- %s\n' "${missing_repos[@]}" >&2
    echo >&2
    echo >&2 "See their respective READMEs on where to clone them to"
    echo >&2 "or set/update the 'EXTRA_JUST_ROOTS' environment variable."
    print_mitigation_help '--ignore-missing-repos'
    exit 1
  else
    echo >&2
    echo >&2 "Warning: Missing repositories:"
    printf -- '- %s\n' "${missing_repos[@]}" >&2
  fi
fi

# Report missing files
if [[ ${#missing_files[@]} -gt 0 ]]; then
  if [[ "$IGNORE_MISSING_FILES" != "true" ]]; then
    echo >&2
    echo >&2 "Error: Missing files:"
    printf -- '- %s\n' "${missing_files[@]}" >&2
    echo >&2
    echo >&2 "You may need to update the respective repositories."
    print_mitigation_help '--ignore-missing-files'
    exit 1
  else
    echo >&2
    echo >&2 "Warning: Missing files:"
    printf -- '- %s\n' "${missing_files[@]}" >&2
  fi
fi

# Replace repo:repo_path pairs with mapped paths and build bash array
mapped_lines=()
while IFS= read -r line; do
  # Skip empty lines
  [[ -n "$line" ]] || continue

  mapped_line="$line"
  # Find all repo:repo_path patterns and replace them
  while [[ "$mapped_line" =~ ([^[:space:]#,]+:[^[:space:],]+) ]]; do
    repo_path="${BASH_REMATCH[1]}"
    if [[ ! -v repo_path_to_path["$repo_path"] ]]; then
      # Should have been reported above, so we silently ignore this import here
      continue 2
    fi
    mapped_path="${repo_path_to_path["$repo_path"]}"
    mapped_line="${mapped_line/"$repo_path"/"$mapped_path"}"
  done

  mapped_lines+=("$mapped_line")
done <"$default_just_files_filename"

# Print import statements
for item in "${mapped_lines[@]}"; do
  if [[ "$item" == *" #"* ]]; then
    # Extract the part before " #" and the comment part
    before_comment="${item%% #*}"
    comment_part=" #${item#* #}"
    echo "import '$before_comment'$comment_part"
  else
    # No comment, replace the whole item
    echo "import '$item'"
  fi
done
