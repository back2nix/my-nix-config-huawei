#!/usr/bin/env bash

print_files() {
  local directory="$1"
  local current_path="$2"
  local include_patterns="$3"
  local exclude_patterns="$4"

  for file in "$directory"/*; do
    local relative_path="${current_path}$(basename "$file")"
    if [ -d "$file" ]; then
      print_files "$file" "${relative_path}/" "$include_patterns" "$exclude_patterns"
    elif [ -f "$file" ]; then
      if check_file "$relative_path" "$include_patterns" "$exclude_patterns"; then
        echo "File: $relative_path"
        echo '```'
        cat "$file"
        echo '```'
        echo
      fi
    fi
  done
}

check_file() {
  local file_path="$1"
  local include_patterns="$2"
  local exclude_patterns="$3"
  local filename=$(basename "$file_path")
  local ext="${filename##*.}"

  # Если список исключений не пуст и файл соответствует паттерну, исключаем файл
  if [ -n "$exclude_patterns" ]; then
    IFS=',' read -ra exclude_array <<< "$exclude_patterns"
    for pattern in "${exclude_array[@]}"; do
      if [[ "$file_path" =~ $pattern || "$filename" =~ $pattern || "$ext" == "$pattern" ]]; then
        return 1
      fi
    done
  fi

  # Если список включений пуст, включаем все неисключенные файлы
  if [ -z "$include_patterns" ]; then
    return 0
  fi

  # Если список включений не пуст, проверяем соответствие файла паттерну
  IFS=',' read -ra include_array <<< "$include_patterns"
  for pattern in "${include_array[@]}"; do
    if [[ "$file_path" =~ $pattern || "$filename" =~ $pattern || "$ext" == "$pattern" ]]; then
      return 0
    fi
  done

  return 1
}

print_usage() {
  echo "Usage: $0 <directory> [--include|-i patterns] [--exclude|-e patterns]"
  echo "Example: $0 /path/to/directory -i go,md,txt,hello.txt,folder/hello.txt -e log,tmp,plugin.nix,folder/excluded.txt"
  exit 1
}

if [ "$#" -lt 1 ]; then
  print_usage
fi

directory="$1"
shift

include_patterns=""
exclude_patterns=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include|-i)
      include_patterns="$2"
      shift 2
      ;;
    --exclude|-e)
      exclude_patterns="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

print_files "$directory" "" "$include_patterns" "$exclude_patterns"
