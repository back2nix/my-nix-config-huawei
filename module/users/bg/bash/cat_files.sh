#!/usr/bin/env bash

print_files() {
  local directory="$1"
  local prefix="$2"

  for file in "$directory"/*; do
    if [ -d "$file" ]; then
      print_files "$file" "$prefix$(basename "$file")/"
    elif [ -f "$file" ]; then
      echo "File: $prefix$(basename "$file")"
      echo '```'
      cat "$file"
      echo '```'
      echo
    fi
  done
}

print_files "$1" ""
