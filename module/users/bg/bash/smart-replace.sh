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

check_file() {
    local file="$1"
    local filename=$(basename "$file")
    local ext="${filename##*.}"

    # Если список исключений не пуст и файл соответствует паттерну, исключаем файл
    if [ -n "$exclude_patterns" ]; then
        IFS=',' read -ra exclude_array <<< "$exclude_patterns"
        for pattern in "${exclude_array[@]}"; do
            if [[ "$filename" == $pattern || "$ext" == "$pattern" ]]; then
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
        if [[ "$filename" == $pattern || "$ext" == "$pattern" ]]; then
            return 0
        fi
    done

    return 1
}

if $whole_word; then
    sed_command="s/\b$old_word\b/$new_word/g"
else
    sed_command="s/$old_word/$new_word/g"
fi

total_changes=0
total_files=0

while IFS= read -r -d '' file; do
    if [ ! -f "$file" ] || ! check_file "$file"; then
        continue
    fi

    # Выполняем замену и подсчитываем количество изменений
    changes=$(sed -i.bak "$sed_command" "$file" && diff "$file.bak" "$file" | grep -c '^<')

    if [ "$changes" -gt 0 ]; then
        echo "Made $changes replacement(s) in $file"
        total_changes=$((total_changes + changes))
        total_files=$((total_files + 1))
    fi

    # Удаляем резервную копию файла
    rm "$file.bak"
done < <(find "$directory" -type f -print0)

echo "Total: Made $total_changes replacement(s) in $total_files file(s)"

# Переименование директории, если указан флаг -m
if $move_directory; then
    if [ "$directory" = "." ]; then
        # Если директория не указана явно, используем текущую директорию
        current_dir=$(pwd)
        parent_dir=$(dirname "$current_dir")
        dir_name=$(basename "$current_dir")
    else
        # Если директория указана явно, используем её
        parent_dir=$(dirname "$directory")
        dir_name=$(basename "$directory")
    fi

    new_dir_name="${dir_name//$old_word/$new_word}"

    if [ "$dir_name" != "$new_dir_name" ]; then
        new_path="$parent_dir/$new_dir_name"
        mv "$(realpath "$directory")" "$new_path"
        echo "Renamed directory '$(realpath "$directory")' to '$new_path'"

        # Если мы переименовали текущую директорию, переходим в неё
        if [ "$directory" = "." ]; then
            cd "$new_path"
            echo "Moved to the renamed directory: $new_path"
        fi
    else
        echo "Directory name unchanged."
    fi
fi
