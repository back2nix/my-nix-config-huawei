#!/usr/bin/env bash

print_file_content() {
  local file="$1"
  echo "File: $file"
  echo '```'
  if [ "$keep_comments" = true ]; then
    cat "$file"
  else
    # Remove both // and # comments
    sed -e 's/^\s*\/\/.*$//' -e 's/^\s*#.*$//' -e '/^\s*$/d' "$file"
  fi
  echo '```'
  echo
}

print_usage() {
  echo "Usage: $0 [-i file ...] [-e pattern ...] [--keep-comments]"
  echo "Example: $0 -i frontend/package.json -i backend/main.go -e .log -e .tmp"
  echo "Use -i to specify files to include"
  echo "Use -e to specify patterns to exclude"
  echo "Use --keep-comments to preserve comments in the output"
  exit 1
}

# Initialize arrays and flags
include_array=()
exclude_array=()
keep_comments=false

# Parse arguments
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

# Function to check if a file should be excluded
should_exclude() {
  local file="$1"
  for pattern in "${exclude_array[@]}"; do
    if [[ "$file" =~ $pattern ]]; then
      return 0
    fi
  done
  return 1
}

# Process each included file
for file in "${include_array[@]}"; do
  if [ -f "$file" ]; then
    if ! should_exclude "$file"; then
      print_file_content "$file"
    fi
  else
    echo "Warning: File not found - $file"
  fi
done

# If no files were specified, print usage
if [ ${#include_array[@]} -eq 0 ]; then
  print_usage
fi
