#!/usr/bin/env bash

print_usage() {
    echo "Usage: $0 <old_word> <new_word> <directory> [-w] [<file_pattern>]"
    echo "  -w               Match whole words only"
    echo "  <file_pattern>   Optional file pattern (e.g., '*.txt')"
    echo "Example: $0 old new /path/to/directory -w '*.md'"
    exit 1
}

if [ "$#" -lt 3 ]; then
    print_usage
fi

old_word="$1"
new_word="$2"
directory="$3"
shift 3

whole_word=false
file_pattern="*"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w)
            whole_word=true
            shift
            ;;
        *)
            file_pattern="$1"
            shift
            ;;
    esac
done

if [ ! -d "$directory" ]; then
    echo "Error: Directory '$directory' not found."
    exit 1
fi

if $whole_word; then
    sed_command="s/\b$old_word\b/$new_word/g"
else
    sed_command="s/$old_word/$new_word/g"
fi

total_changes=0
total_files=0

while IFS= read -r -d '' file; do
    if [ ! -f "$file" ]; then
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
done < <(find "$directory" -type f -name "$file_pattern" -print0)

echo "Total: Made $total_changes replacement(s) in $total_files file(s)"
