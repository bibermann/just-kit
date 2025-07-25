#!/usr/bin/env bash
set -euo pipefail

recipe_running_this_script='pick'
recipe_checking_relevance='_check-justile-relevance'
auto_generated_hint="# Note: The imports above were generated by \`just $recipe_running_this_script\`"

print_just_source_hint() {
  echo >&2 "Hint: You need to run 'source just-bash' in every new shell to profit."
}

CHECK_RELEVANCE="$1"

[ -f .env ] && source .env

# Exit if neither justfile not Justfile exists
JUSTFILE=$(find . -maxdepth 1 -type f -name "[Jj]ustfile" -o -name "\.[Jj]ustfile" | head -n1)
[ -n "$JUSTFILE" ] || {
  echo >&2 "ERROR: No justfile found."
  exit 1
}

echo "Using '$(realpath "$JUSTFILE")'"

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

paths=()
real_paths=()
search_patterns=()
search_justfiles() {
  local pattern="$1"
  local dir="$2"
  local prefix="$3"
  shift 3
  local extra_find_args=("$@")

  if exists_in_array "$pattern" "${search_patterns[@]}"; then
    echo "Skipping $pattern (already searched)"
    return
  else
    search_patterns+=("$pattern")
  fi

  echo -n "Searching $pattern: "
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
        paths+=("$prefix$path")
        real_paths+=("${dir%%/}/$path")
        ((count_unique += 1))
      else
        ((count_duplicates += 1))
      fi
    done < <(find "$dir" "${extra_find_args[@]}" -name "*.just" -type f -printf "%P\n" | sort)
  fi
  echo -n "$count_unique found"
  if [[ $count_duplicates -gt 0 ]]; then
    echo -n " (+$count_duplicates duplicates)"
  fi
  echo
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
    CURRENT_DIR="$EXTRA_DIR"
    CURRENT_PREFIX="${CURRENT_DIR/$HOME/\~}/"

    search_justfiles "${CURRENT_DIR%%/}/**.just" "$CURRENT_DIR" "$CURRENT_PREFIX"

    if [ "$CURRENT_DIR" = "/" ]; then
      continue
    fi

    CURRENT_DIR=$(dirname "$CURRENT_DIR")
    CURRENT_PREFIX="${CURRENT_DIR/$HOME/\~}/"

    while :; do
      search_justfiles "${CURRENT_DIR%%/}/*.just" "$CURRENT_DIR" "$CURRENT_PREFIX" -maxdepth 1
      search_justfiles "${CURRENT_DIR%%/}/.just/**.just" "${CURRENT_DIR%%/}/.just" "$CURRENT_PREFIX.just/"

      if [ "$CURRENT_DIR" = "/" ]; then
        break
      fi

      CURRENT_DIR=$(dirname "$CURRENT_DIR")
      CURRENT_PREFIX="${CURRENT_DIR/$HOME/\~}/"
    done
  done
fi

function print_clean_path() {
  local path="$1"
  local name=$(basename "$path" .just)
  local dirname=$(dirname "$path")

  # Split dirname into components and filter out `.`, `..` and `.just`
  local parts=()
  local IFS='/'
  for part in $dirname; do
    if [[ "$part" && "$part" != "~" && "$part" != "." && "$part" != ".." && "$part" != ".just" ]]; then
      parts+=("$part")
    fi
  done

  ## Join the filtered parts with » character
  #local joined_parts=""
  #if [ ${#parts[@]} -gt 0 ]; then
  #  joined_parts="${parts[0]}"
  #  for ((i=1; i<${#parts[@]}; i++)); do
  #    joined_parts+=" » ${parts[$i]}"
  #  done
  #  echo "$name ($joined_parts)"
  #else
  #  echo "$name"
  #fi

  # Join the filtered parts with « character
  local joined_parts=""
  if [ ${#parts[@]} -gt 0 ]; then
    joined_parts="${parts[-1]}"
    for ((i = ${#parts[@]} - 2; i >= 0; i--)); do
      joined_parts+=" « ${parts[$i]}"
    done
    echo "$name ($joined_parts)"
  else
    echo "$name"
  fi
}

justfile_running_this_script=
function get_justfile_recipes() {
  recipes=  # newline delimited list
  recipe_empty_list=  # newline delimited list

  local path="$1"
  local output=""
  local missing_deps=()
  local need_allow_duplicate_recipes=false
  local temp_file

  local full_path="$(realpath "${path/\~/$HOME}")"

  local recipe_body
  local recipe_comment

  while true; do
    temp_file="$(mktemp)"
    trap 'rm -f "$temp_file"; trap - EXIT' RETURN EXIT

    {
      if $need_allow_duplicate_recipes; then
        echo 'set allow-duplicate-recipes'
      fi
      for dep in "${missing_deps[@]}"; do
        echo "$dep *ARGS:"
      done
      echo "import '$full_path'"
    } >"$temp_file"

    if grep -q "^${recipe_running_this_script}[: ]" "$full_path" 2>/dev/null; then
      if [[ ! -z "$justfile_running_this_script" ]]; then
        echo >&2 "Error: Multiple justfiles containing recipe '$recipe_running_this_script': '$justfile_running_this_script', '$path'"
        exit 1
      fi
      justfile_running_this_script="$path"
      echo >&2 "Hiding '$path' (contains recipe running this script)"
      return 1
    fi

    if output="$(JUST_UNSTABLE=1 JUST_COLOR=never just --allow-missing --dump --dump-format json -f "$temp_file" 2>&1)"; then
      # Run and evaluate $recipe_checking_relevance recipe if it exists
      if [[ "$CHECK_RELEVANCE" == "true" ]] && grep -q "^$recipe_checking_relevance:" "$full_path" 2>/dev/null; then
        if JUST_UNSTABLE=1 JUST_COLOR=never just --allow-missing -f "$temp_file" -d "$PWD" "$recipe_checking_relevance" >/dev/null 2>&1; then
          :
        else
          echo >&2 "Hiding '$path' (recipe '$recipe_checking_relevance' returned non-zero exit code $?)"
          return 1
        fi
      fi

      # Print the JSON output
      while IFS= read -r recipe; do
        if ! printf '%s\0' "${missing_deps[@]}" | grep -Fxqz -- "$recipe"; then
          if [[ ! -z "$recipes" ]]; then
            recipes+=$'\n'
            recipe_empty_list+=$'\n'
          fi
          recipes+="$recipe"
          recipe_body="$(jq -r --arg recipe "$recipe" '.recipes[$recipe].body' <<<"$output")"
          recipe_comment="$(jq -r --arg recipe "$recipe" '.recipes[$recipe].doc // ""' <<<"$output")"
          if [[ "$recipe_body" == "[]" ]] || [[ "$recipe_comment" == "dummy" ]]; then
            recipe_empty_list+="1"
          else
            recipe_empty_list+="0"
          fi
        fi
      done < <(jq -r '.recipes | keys . []' <<<"$output")
      return 0
    elif [[ "$output" =~ error:.*unknown\ dependency\ \`(.*)\` ]]; then
      missing_deps+=("${BASH_REMATCH[1]}")
    elif [[ "$output" =~ error:\ Recipe\ \`.*\`\ first\ defined\ .*\ redefined\ .* ]]; then
      need_allow_duplicate_recipes=true
    else
      echo 1>&2 "$output"
      return 1
    fi

    rm -f "$temp_file"
    trap - RETURN EXIT
  done
}

# Sort paths by filename first, then by full absolute path
readarray -t sorted_paths < <(
  for path in "${paths[@]}"; do
    printf '%s\t%s\t%s\n' "$(basename "$path")" "$(realpath "${path/#\~/$HOME}")" "$path"
  done | sort -k1,1 -k2,2 | cut -f3
)

# Get options
options=()
known_imports=()
declare -A name_counts
declare -A unique_name_to_path
declare -A overrides_array
declare -A relevant_path_to_recipes
declare -A relevant_path_to_recipe_empty_list
for path in "${sorted_paths[@]}"; do
  if get_justfile_recipes "$path"; then
    relevant_path_to_recipes[$path]="$recipes"
    relevant_path_to_recipe_empty_list[$path]="$recipe_empty_list"
  else
    continue
  fi

  name="$(print_clean_path "$path")"
  if [[ ! -v name_counts[$name] ]]; then
    name_counts[$name]=1
    unique_name="$name"
  else
    name_counts[$name]=$((name_counts[$name] + 1))
    unique_name="${name} ${name_counts[$name]}"
  fi
  unique_name_to_path[$unique_name]="$path"

  state=off
  OVERRIDES=""
  while read -r line; do
    if [[ "$line" =~ ^import\ +[\"\'](.*)[\"\'](.*)$ ]]; then
      imported_path="${BASH_REMATCH[1]}"
      remainder="${BASH_REMATCH[2]}"

      realpath_imported="$(realpath "${imported_path/\~/$HOME}" 2>/dev/null || echo "$imported_path")"
      realpath_path="$(realpath "${path/\~/$HOME}" 2>/dev/null || echo "$path")"

      if [[ "$realpath_imported" == "$realpath_path" ]]; then
        known_imports+=("$realpath_imported")
        state=on
        if [[ "$remainder" =~ \#\ *overrides\ +(.*) ]]; then
          OVERRIDES="$imported_path"
        fi
      fi
    fi
  done <"$JUSTFILE"
  [[ -n "$OVERRIDES" ]] && overrides_array[$path]="$OVERRIDES"

  options+=("$unique_name" "$path" "$state")
done

# Present options
# https://serverfault.com/questions/144939/multi-select-menu-in-bash-script
cmd=(dialog --separate-output --checklist "Select options:" 0 0 0)
if ! choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty); then
  clear -x
  print_just_source_hint
  exit 0
fi
clear -x

declare -A path_to_recipes
while IFS= read -r choice; do
  [ -z "$choice" ] && continue
  path="${unique_name_to_path[$choice]}"
  path_to_recipes[$path]="${relevant_path_to_recipes[$path]}"
done <<<"$choices"

## Print dependencies for each path
#for path in "${!path_to_recipes[@]}"; do
#  echo "Recipes for $path:"
#  echo "  ${path_to_recipes[$path]}"
#done

# Find path pairs that share recipes
declare -A conflicts
declare -A auto_preferences
declare -a path_list=("${!path_to_recipes[@]}")
for ((i = 0; i < ${#path_list[@]}; i++)); do
  path1="${path_list[i]}"
  readarray -t recipes1 <<<"${path_to_recipes[$path1]}"
  readarray -t empties1 <<<"${relevant_path_to_recipe_empty_list[$path1]}"

  for ((j = i + 1; j < ${#path_list[@]}; j++)); do
    path2="${path_list[j]}"
    readarray -t recipes2 <<<"${path_to_recipes[$path2]}"
    readarray -t empties2 <<<"${relevant_path_to_recipe_empty_list[$path2]}"

    shared_recipes=()
    for recipe1 in "${recipes1[@]}"; do
      if [[ -z "$recipe1" || "$recipe1" == "$recipe_checking_relevance" ]]; then
        continue
      fi
      for recipe2 in "${recipes2[@]}"; do
        if [[ "$recipe1" == "$recipe2" ]]; then
          shared_recipes+=("$recipe1")
          break
        fi
      done
    done

    if [[ ${#shared_recipes[@]} -gt 0 ]]; then
      conflicts["$path1,$path2"]="${shared_recipes[*]}"

      # Check if all shared recipes are non-empty for path2 and empty for path1
      all_path2_non_empty=1
      all_path1_empty=1

      # Check if all shared recipes are non-empty for path1 and empty for path2
      all_path1_non_empty=1
      all_path2_empty=1

      for shared_recipe in "${shared_recipes[@]}"; do
        # Find indices of the shared recipe in both paths
        for ((k = 0; k < ${#recipes1[@]}; k++)); do
          if [[ "${recipes1[k]}" == "$shared_recipe" ]]; then
            if [[ "${empties1[k]}" == "1" ]]; then
              all_path1_non_empty=0
            else
              all_path1_empty=0
            fi
            break
          fi
        done

        for ((k = 0; k < ${#recipes2[@]}; k++)); do
          if [[ "${recipes2[k]}" == "$shared_recipe" ]]; then
            if [[ "${empties2[k]}" == "1" ]]; then
              all_path2_non_empty=0
            else
              all_path2_empty=0
            fi
            break
          fi
        done
      done

      # Assign auto_preferences based on the conditions
      if [[ $all_path2_non_empty -eq 1 && $all_path1_empty -eq 1 ]]; then
        auto_preferences["$path1,$path2"]="$path2"
      elif [[ $all_path1_non_empty -eq 1 && $all_path2_empty -eq 1 ]]; then
        auto_preferences["$path1,$path2"]="$path1"
      else
        auto_preferences["$path1,$path2"]=
      fi
    fi
  done
done

# TODO: consider using real arrays in the hash map
#       using `declare -p` and `eval`,
#       may be slow but is more safe:
#       https://stackoverflow.com/a/71570497/704821

# Initialize directed graph to track dependencies
declare -A graph
declare -A graph_reversed
for path in "${path_list[@]}"; do
  graph[$path]=""
  graph_reversed[$path]=""
done

# For each conflict, ask user to resolve
for conflict_paths in "${!conflicts[@]}"; do
  IFS=',' read -r path1 path2 <<<"$conflict_paths"
  shared_recipes_text="${conflicts[$conflict_paths]}"
  auto_preference="${auto_preferences[$conflict_paths]}"

  # Sort alphabetically
  if [[ "$path1" > "$path2" ]]; then
    temp="$path1"
    path1="$path2"
    path2="$temp"
  fi

  if [[ -v "overrides_array[$path1]" ]]; then
    IFS=',' read -ra override_paths <<<"${overrides_array[$path1]}"
    for override_path in "${override_paths[@]}"; do
      if [[ "$override_path" == "$path2" ]]; then
        graph[$path1]+=" $path2"
        graph_reversed[$path2]+=" $path1"
        continue 2
      fi
    done
  fi

  if [[ -v "overrides_array[$path2]" ]]; then
    IFS=',' read -ra override_paths <<<"${overrides_array[$path2]}"
    for override_path in "${override_paths[@]}"; do
      if [[ "$override_path" == "$path1" ]]; then
        graph[$path2]+=" $path1"
        graph_reversed[$path1]+=" $path2"
        continue 2
      fi
    done
  fi

  if [[ "$auto_preference" == $path1 ]]; then
    choice=1
    interactive=0
  elif [[ "$auto_preference" == $path2 ]]; then
    choice=2
    interactive=0
  else
    choice=
    interactive=1
  fi

  if [[ "$interactive" == "1" ]]; then
    echo -e "\nConflict between paths:"
    echo "1. $path1"
    echo "2. $path2"
    echo "Shared recipes: $shared_recipes_text"
  fi

  while true; do
    if [[ "$interactive" == "1" ]]; then
      read -p "Which path should override the other? (1/2): " choice
    fi
    if [[ "$choice" == "1" ]]; then
      graph[$path1]+=" $path2"
      graph_reversed[$path2]+=" $path1"
      break
    elif [[ "$choice" == "2" ]]; then
      graph[$path2]+=" $path1"
      graph_reversed[$path1]+=" $path2"
      break
    else
      echo "Invalid choice. Please enter 1 or 2."
    fi
  done
done

declare -a sorted_paths=()
declare -A visited
declare -A temp_mark
declare -a original_order
original_order=("${paths[@]}")
topological_sort() {
  local node="$1"

  if [[ -v visited[$node] ]]; then
    # Already in sorted_paths
    return 0
  fi

  # Check for cycles (temporary mark)
  if [[ -v temp_mark[$node] ]]; then
    echo "Error: Circular dependency detected!" >&2
    exit 1
  fi

  # Mark node temporarily
  temp_mark[$node]=1

  # Visit all dependencies, preserving original order
  local deps=()
  for dep in "${original_order[@]}"; do
    [[ " ${graph_reversed[$node]} " =~ " $dep " ]] && deps+=("$dep")
  done

  for dep in "${deps[@]}"; do
    topological_sort "$dep"
  done

  # Remove temporary mark
  unset 'temp_mark[$node]'

  # Add to sorted_paths
  visited[$node]=1
  sorted_paths+=("$node")
}

# Perform topological sort for each node in original order
deps=()
for dep in "${original_order[@]}"; do
  [[ " ${!graph_reversed[*]} " =~ " $dep " ]] && deps+=("$dep")
done
for node in "${deps[@]}"; do
  if [[ ! -v visited[$node] ]]; then
    topological_sort "$node"
  fi
done

## Reverse the sorted paths to get the correct order,
## required when https://github.com/casey/just/issues/2540 is fixed.
#declare -a final_order=()
#for ((i = ${#sorted_paths[@]} - 1; i >= 0; i--)); do
#  final_order+=("${sorted_paths[i]}")
#done
final_order=("${sorted_paths[@]}")

if [[ ! -z "$justfile_running_this_script" ]]; then
  final_order+=("$justfile_running_this_script")
fi

temp_file="$(mktemp)"
trap 'echo "removing $temp_file" && rm -f "$temp_file"' EXIT

for path in "${final_order[@]}"; do
  deps="${graph[$path]:-}" # using empty default because "$justfile_running_this_script" will not be in graph
  if [ -n "$deps" ]; then
    deps="${deps# }" # remove leading space
    echo >>"$temp_file" "import '$path' # overrides ${deps// /,}"
  else
    echo >>"$temp_file" "import '$path'"
  fi
done
echo -e "$auto_generated_hint\n" >>"$temp_file"

skip_next_empty_line=0
while IFS= read -r line; do
  if [[ "$line" == "$auto_generated_hint" ]]; then
    skip_next_empty_line=1
    continue
  fi
  if [[ $skip_next_empty_line -eq 1 && -z "$line" ]]; then
    skip_next_empty_line=0
    continue
  fi
  skip_next_empty_line=0

  if [[ "$line" =~ ^import\ +[\"\'](.*)[\"\'] ]]; then
    imported_path="${BASH_REMATCH[1]}"
    realpath_imported="$(realpath "${imported_path/\~/$HOME}" 2>/dev/null || echo "$imported_path")"
    for realpath_path in "${known_imports[@]}"; do
      if [[ "$realpath_imported" == "$realpath_path" ]]; then
        continue 2  # skip removed paths imported before
      fi
    done
    for path in "${final_order[@]}"; do
      realpath_path="$(realpath "${path/\~/$HOME}" 2>/dev/null || echo "$path")"
      if [[ "$realpath_imported" == "$realpath_path" ]]; then
        continue 2  # skip paths that were selected for import
      fi
    done
  fi
  echo "$line" >>"$temp_file"
done <"$JUSTFILE"

mv "$temp_file" "$JUSTFILE"
trap - EXIT

print_just_source_hint
