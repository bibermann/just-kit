#!/usr/bin/env bash
set -euo pipefail

repo_path="${1:-.}"
remote_name="${2:-origin}"

# Get the remote URL
remote_url=$(git -C "$repo_path" remote get-url "$remote_name" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$remote_url" ]; then
  echo "Error: Could not retrieve remote URL for '$remote_name'" >&2
  return 1
fi

# Normalize the URL to HTTPS format

# Handle SSH URLs (git@host:user/repo.git or ssh://git@host/user/repo.git)
if [[ "$remote_url" =~ ^git@([^:]+):(.+)$ ]]; then
  # Format: git@github.com:user/repo.git
  host="${BASH_REMATCH[1]}"
  path="${BASH_REMATCH[2]}"
  normalized_url="https://${host}/${path}"
elif [[ "$remote_url" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
  # Format: ssh://git@github.com/user/repo.git
  host="${BASH_REMATCH[1]}"
  path="${BASH_REMATCH[2]}"
  normalized_url="https://${host}/${path}"
elif [[ "$remote_url" =~ ^https?://(.+)$ ]]; then
  # Already HTTP/HTTPS, keep as is
  normalized_url="$remote_url"
else
  # Unknown format, return as is
  normalized_url="$remote_url"
fi

# Remove .git suffix if present
normalized_url="${normalized_url%.git}"

echo "$normalized_url"
