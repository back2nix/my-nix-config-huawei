#!/usr/bin/env bash

print_usage() {
  echo "Usage: $0 <old_word> <new_word> [options]"
  echo "Options:"
  echo "  -d <directory>         Directory to process (default: current directory)"
  echo "  -w                     Match whole words only"
  echo "  -m                     Move (rename) the directory after replacement"
  echo "  -i <include_patterns>  Comma-separated list of patterns to include"
  echo "  -e <exclude_patterns>  Comma-separated list of patterns to exclude"
  echo "Example: $0 old new -d /path/to/directory -w -m -i go,md,txt,hello.txt -e log,tmp,plugin.nix"
  exit 1
}

if [ "$#" -lt 2 ]; then
  print_usage
fi

old_word="$1"
new_word="$2"
shift 2

directory="."
whole_word=false
move_directory=false
include_patterns=""
exclude_patterns=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  -d)
    directory="$2"
    shift 2
    ;;
  -w)
    whole_word=true
    shift
    ;;
  -m)
    move_directory=true
    shift
    ;;
  -i)
    include_patterns="$2"
    shift 2
    ;;
  -e)
    exclude_patterns="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    print_usage
    ;;
  esac
done

if [ ! -d "$directory" ]; then
  echo "Error: Directory '$directory' not found."
  exit 1
fi

create_sed_regex() {
  local old="$1"
  if $whole_word; then
    echo "s/(^|[^[:alnum:]])$(echo "$old" | sed 's/[\/&]/\\&/g')($|[^[:alnum:]])/\1$(echo "$new_word" | sed 's/[\/&]/\\&/g')\2/g"
  else
    echo "s/$(echo "$old" | sed 's/[\/&]/\\&/g')/$(echo "$new_word" | sed 's/[\/&]/\\&/g')/g"
  fi
}

sed_command=$(create_sed_regex "$old_word")

total_changes=0
total_files=0

rg_include_args=()
rg_exclude_args=()

# Формирование аргументов включения
if [ -n "$include_patterns" ]; then
  IFS=',' read -ra include_array <<< "$include_patterns"
  for pattern in "${include_array[@]}"; do
    if [[ "$pattern" == *.* ]]; then
      rg_include_args+=(-g "**/$pattern")
    else
      rg_include_args+=(-g "**/*.$pattern")
    fi
  done
fi

# Формирование аргументов исключения
if [ -n "$exclude_patterns" ]; then
  IFS=',' read -ra exclude_array <<< "$exclude_patterns"
  for pattern in "${exclude_array[@]}"; do
    if [[ "$pattern" == *.* ]]; then
      rg_exclude_args+=(-g "!**/$pattern")
    else
      rg_exclude_args+=(-g "!**/*.$pattern")
    fi
  done
fi

# Сборка команды ripgrep
rg_command=(rg --files --hidden --follow)
rg_command+=("${rg_include_args[@]}" "${rg_exclude_args[@]}" "$directory")

while IFS= read -r file; do
  # Пропускаем файлы без прав записи
  if [ ! -w "$file" ]; then
    echo "Skipping read-only file: $file"
    continue
  fi

  # Создаем резервную копию и считаем изменения
  changes=0
  if sed -i.bak -E "$sed_command" "$file" 2>/dev/null; then
    # Надежный подсчет измененных строк
    changes=$(diff --unchanged-line-format= --old-line-format= --new-line-format='%' "$file.bak" "$file" | wc -c)
    changes=$((changes))
  fi

  # Удаляем резервную копию
  rm -f "$file.bak" 2>/dev/null

  if (( changes > 0 )); then
    echo "Made $changes replacement(s) in $file"
    total_changes=$((total_changes + changes))
    total_files=$((total_files + 1))
  fi
done < <( "${rg_command[@]}" 2>/dev/null )

echo "Total: Made $total_changes replacement(s) in $total_files file(s)"

# Обработка переименования директории
if $move_directory; then
  dir_path=$(realpath "$directory")
  parent_dir=$(dirname "$dir_path")
  dir_name=$(basename "$dir_path")
  new_dir_name="${dir_name//$old_word/$new_word}"

  if [ "$dir_name" != "$new_dir_name" ]; then
    new_path="$parent_dir/$new_dir_name"
    if mv "$dir_path" "$new_path" 2>/dev/null; then
      echo "Renamed directory '$dir_path' to '$new_path'"
      [ "$directory" = "." ] && cd "$new_path" || true
    else
      echo "Error: Failed to rename directory (check permissions)"
    fi
  else
    echo "Directory name unchanged."
  fi
fi
