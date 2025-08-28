#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(dirname -- "$(dirname -- "${BASH_SOURCE[0]}")")"
GIT_ROOT="$(git rev-parse --show-toplevel)"

justfile="${1:-justfile}"
default_just_files_filename='.just.lock'

if ! [[ -f "$justfile" ]]; then
  echo "Error: $justfile not found" >&2
  exit 1
fi

get_subpath() {
    echo "${1#${2%/}/}"
}

declare -A path_to_git_root
declare -A path_to_repo_path

mapfile -t paths < <("$ROOT_DIR/pick/search-just-files.sh")
for path in "${paths[@]}"; do
  git_root="$(git -C "$(dirname -- "${path/\~/$HOME}")" rev-parse --show-toplevel)"
  path_to_git_root["$path"]="$git_root"

  repo_path="$(get_subpath "$(realpath "${path/\~/$HOME}")" "$git_root")"
  if [[ "$GIT_ROOT" == "$git_root" ]]; then
    path_to_repo_path["$path"]="$repo_path"
  else
    repo="$("$ROOT_DIR/pick/get-git-remote.sh" "$git_root")"
    path_to_repo_path["$path"]="$repo:$repo_path"
  fi
done

# Process justfile and convert import statements
output_lines=()
while IFS= read -r line; do
  # Skip empty lines and non-import lines
  [[ -n "$line" ]] || continue
  [[ "$line" =~ ^[[:space:]]*import[[:space:]] ]] || continue

  # Extract the import path and comment
  if [[ "$line" =~ ^[[:space:]]*import[[:space:]]+\'([^\']+)\'[[:space:]]*(.*)$ ]]; then
    import_path="${BASH_REMATCH[1]}"
    comment_part="${BASH_REMATCH[2]}"

    # Convert main import path to repo:repo_path format
    if [[ -v path_to_repo_path["$import_path"] ]]; then
      if [[ "${path_to_git_root["$import_path"]}" == "$ROOT_DIR" ]]; then
        # Skip just-kit imports (pick)
        continue
      fi

      repo_path="${path_to_repo_path["$import_path"]}"

      if [[ -n "$comment_part" ]]; then
        # Extract all file paths from the comment (similar to how reverse script extracts repo:repo_path patterns)
        mapfile -t file_paths < <(echo "$comment_part" | grep -oE '[^[:space:]#,]+\.just' || true)

        # Sort file paths by length (descending) to avoid partial matches
        mapfile -t file_paths < <(printf '%s\n' "${file_paths[@]}" | awk '{ print length($0) " " $0; }' | sort -rn | cut -d' ' -f2-)

        processed_comment="$comment_part"
        for file_path in "${file_paths[@]}"; do
          if [[ -v path_to_repo_path["$file_path"] ]]; then
            processed_comment="${processed_comment//$file_path/${path_to_repo_path["$file_path"]}}"
          else
            echo "Warning: Path '$file_path' in comment not found in available just files" >&2
          fi
        done

        output_lines+=("$repo_path $processed_comment")
      else
        output_lines+=("$repo_path")
      fi
    else
      echo "Warning: Path '$import_path' not found in available just files" >&2
    fi
  fi

done < "$justfile"

# Write to .just.lock
printf '%s\n' "${output_lines[@]}" > "$default_just_files_filename"
echo "Generated $default_just_files_filename with ${#output_lines[@]} entries"
