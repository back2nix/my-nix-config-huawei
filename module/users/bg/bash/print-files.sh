#!/usr/bin/env bash

print_file_content() {
  local file="$1"
  echo "File: $file"
  echo '```'
  if [ "$keep_comments" = true ]; then
    if [ "$line_numbers" = true ]; then
      nl -ba "$file"
    else
      cat "$file"
    fi
  else
    if [ "$line_numbers" = true ]; then
      sed -e 's/^\s*\/\/.*$//' -e 's/^\s*#.*$//' -e '/^\s*$/d' "$file" | nl -ba
    else
      sed -e 's/^\s*\/\/.*$//' -e 's/^\s*#.*$//' -e '/^\s*$/d' "$file"
    fi
  fi
  echo '```'
  echo
}

print_usage() {
  echo "Usage: $0 [-i file ...] [-t ext1,ext2,...] [-e pattern ...] [--keep-comments] [-r] [-n]"
  echo "Example: $0 -i frontend/package.json -t nix,txt,md -e .log -e .tmp -r -n"
  echo "Use -i to specify files to include"
  echo "Use -t to specify file extensions to include"
  echo "Use -e to specify patterns to exclude"
  echo "Use --keep-comments to preserve comments in the output"
  echo "Use -r for recursive search"
  echo "Use -n to show line numbers"
  exit 1
}

include_array=()
extensions=()
exclude_array=()
keep_comments=false
recursive=false
line_numbers=false

while [[ $# -gt 0 ]]; do
  case "$1" in
  -i)
    include_array+=("$2")
    shift 2
    ;;
  -t)
    IFS=',' read -ra extensions <<<"$2"
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
  -r)
    recursive=true
    shift
    ;;
  -n)
    line_numbers=true
    keep_comments=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    print_usage
    ;;
  esac
done

should_exclude() {
  local file="$1"
  for pattern in "${exclude_array[@]}"; do
    if [[ "$file" =~ $pattern ]]; then
      return 0
    fi
  done
  return 1
}

has_valid_extension() {
  local file="$1"
  local ext="${file##*.}"
  for valid_ext in "${extensions[@]}"; do
    if [[ "$ext" == "$valid_ext" ]]; then
      return 0
    fi
  done
  return 1
}

process_files() {
  local dir="$1"
  local find_args=()
  if [ "$recursive" = true ]; then
    find_args+=("$dir")
  else
    find_args+=("$dir" -maxdepth 1)
  fi

  if [ ${#extensions[@]} -gt 0 ]; then
    find_args+=("(")
    for ext in "${extensions[@]}"; do
      find_args+=(-name "*.$ext" -o)
    done
    unset 'find_args[${#find_args[@]}-1]'
    find_args+=(")")
  fi

  while IFS= read -r -d $'\0' file; do
    if ! should_exclude "$file"; then
      print_file_content "$file"
    fi
  done < <(find "${find_args[@]}" -type f -print0)
}

for file in "${include_array[@]}"; do
  if [ -f "$file" ]; then
    if ! should_exclude "$file"; then
      print_file_content "$file"
    fi
  else
    echo "Warning: File not found - $file"
  fi
done

if [ ${#extensions[@]} -gt 0 ]; then
  process_files "."
fi

if [ ${#include_array[@]} -eq 0 ] && [ ${#extensions[@]} -eq 0 ]; then
  print_usage
fi
