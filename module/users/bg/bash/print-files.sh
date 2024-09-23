#!/usr/bin/env bash

print_files() {
  local directory="$1"
  local current_path="$2"
  local include_patterns=("${include_array[@]}")
  local exclude_patterns=("${exclude_array[@]}")

  for file in "$directory"/*; do
    local relative_path="${current_path}$(basename "$file")"
    if [ -d "$file" ]; then
      print_files "$file" "${relative_path}/"
    elif [ -f "$file" ]; then
      if check_file "$relative_path"; then
        echo "File: $relative_path"
        echo '```'
        if [ "$keep_comments" = true ]; then
          cat "$file"
        else
          # Remove both // and # comments
          sed -e 's/^\s*\/\/.*$//' -e 's/^\s*#.*$//' -e '/^\s*$/d' "$file"
        fi
        echo '```'
        echo
      fi
    fi
  done
}

check_file() {
  local file_path="$1"
  local filename=$(basename "$file_path")
  local ext="${filename##*.}"

  # Check exclude patterns
  for pattern in "${exclude_array[@]}"; do
    if [[ "$file_path" =~ $pattern || "$filename" =~ $pattern || "$ext" == "$pattern" ]]; then
      return 1
    fi
  done

  # If include patterns are empty, include all non-excluded files
  if [ ${#include_array[@]} -eq 0 ]; then
    return 0
  fi

  # Check include patterns
  for pattern in "${include_array[@]}"; do
    if [[ "$file_path" =~ $pattern || "$filename" =~ $pattern || "$ext" == "$pattern" ]]; then
      return 0
    fi
  done

  return 1
}

print_usage() {
  echo "Usage: $0 [directory] [-i pattern ...] [-e pattern ...] [--keep-comments]"
  echo "Example: $0 /path/to/directory -i go -i md -i txt -i hello.txt -i folder/hello.txt -e log -e tmp -e plugin.nix -e folder/excluded.txt"
  echo "If directory is not specified, the current directory (.) will be used."
  echo "By default, both // and # comments are removed. Use --keep-comments to preserve them."
  exit 1
}

# Set default directory to current directory
directory="."

# Check if the first argument is a directory
if [ $# -gt 0 ] && [ -d "$1" ]; then
  directory="$1"
  shift
fi

include_array=()
exclude_array=()
keep_comments=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      include_array+=("$2")
      shift 2
      ;;
    -e)
      exclude_array+=("$2")
      shift 2
      ;;
    --keep-comments)
      keep_comments=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

print_files "$directory" ""
