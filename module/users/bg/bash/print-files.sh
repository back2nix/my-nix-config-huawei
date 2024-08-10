#!/usr/bin/env bash

print_files() {
  local directory="$1"
  local prefix="$2"
  local include_extensions="$3"
  local exclude_extensions="$4"

  for file in "$directory"/*; do
    if [ -d "$file" ]; then
      print_files "$file" "$prefix$(basename "$file")/" "$include_extensions" "$exclude_extensions"
    elif [ -f "$file" ]; then
      if check_extension "$file" "$include_extensions" "$exclude_extensions"; then
        echo "File: $prefix$(basename "$file")"
        echo '```'
        cat "$file"
        echo '```'
        echo
      fi
    fi
  done
}

check_extension() {
  local file="$1"
  local include_extensions="$2"
  local exclude_extensions="$3"
  local ext="${file##*.}"

  # Если список исключений не пуст и расширение в нем, исключаем файл
  if [ -n "$exclude_extensions" ]; then
    IFS=',' read -ra exclude_array <<< "$exclude_extensions"
    for i in "${exclude_array[@]}"; do
      if [ "$i" = "$ext" ]; then
        return 1
      fi
    done
  fi

  # Если список включений пуст, включаем все неисключенные файлы
  if [ -z "$include_extensions" ]; then
    return 0
  fi

  # Если список включений не пуст, проверяем наличие расширения в нем
  IFS=',' read -ra include_array <<< "$include_extensions"
  for i in "${include_array[@]}"; do
    if [ "$i" = "$ext" ]; then
      return 0
    fi
  done

  return 1
}

print_usage() {
  echo "Usage: $0 <directory> [--include|-i file_extensions] [--exclude|-e file_extensions]"
  echo "Example: $0 /path/to/directory -i go,md,txt -e log,tmp"
  exit 1
}

if [ "$#" -lt 1 ]; then
  print_usage
fi

directory="$1"
shift

include_extensions=""
exclude_extensions=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include|-i)
      include_extensions="$2"
      shift 2
      ;;
    --exclude|-e)
      exclude_extensions="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

print_files "$directory" "" "$include_extensions" "$exclude_extensions"
