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
    echo "Usage: $0 [-i pattern ...] [-t ext1,ext2,...] [-e pattern ...] [--keep-comments] [-r] [-n]"
    echo "Example: $0 -i '*.go' -i '*_test.go' -t nix,txt,md -e '*_name.go' -e '.log' -r -n"
    echo "Use -i to specify files/patterns to include"
    echo "Use -t to specify file extensions to include"
    echo "Use -e to specify patterns to exclude"
    echo "Use --keep-comments to preserve comments in the output"
    echo "Use -r for recursive search"
    echo "Use -n to show line numbers"
    exit 1
}

include_patterns=()
extensions=()
exclude_patterns=()
keep_comments=false
recursive=false
line_numbers=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i)
            include_patterns+=("$2")
            shift 2
            ;;
        -t)
            IFS=',' read -ra extensions <<<"$2"
            shift 2
            ;;
        -e)
            exclude_patterns+=("$2")
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
    for pattern in "${exclude_patterns[@]}"; do
        # Если паттерн содержит путь
        if [[ "$pattern" == *"/"* ]]; then
            if [[ "$file" == $pattern ]]; then
                return 0
            fi
        else
            # Для паттернов без пути проверяем только имя файла
            local basename_file
            basename_file=$(basename "$file")
            if [[ "$basename_file" == $pattern ]]; then
                return 0
            fi
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

matches_include_pattern() {
    local filepath="$1"
    for pattern in "${include_patterns[@]}"; do
        # Если паттерн содержит путь, проверяем относительно корня поиска
        if [[ "$pattern" == *"/"* ]]; then
            # Для паттернов с путём, проверяем как точное совпадение, так и glob
            if [[ "$filepath" == $pattern ]] || [[ "$filepath" == *"/$pattern" ]]; then
                return 0
            fi
        else
            # Для паттернов без пути проверяем только имя файла
            local basename_file
            basename_file=$(basename "$filepath")
            if [[ "$basename_file" == $pattern ]]; then
                return 0
            fi
        fi
    done
    return 1
}

process_files() {
    # Определяем корневую директорию для поиска
    local search_root
    # Если в шаблонах есть путь, используем его как основу
    for pattern in "${include_patterns[@]}"; do
        if [[ "$pattern" == *"/"* ]]; then
            search_root=$(dirname "$pattern")
            break
        fi
    done
    # Если путь не найден, используем текущую директорию
    search_root=${search_root:-.}

    local find_cmd="find"
    if [ "$recursive" = true ]; then
        find_cmd="find $search_root"
    else
        find_cmd="find $search_root -maxdepth 1"
    fi

    local ext_condition=""
    if [ ${#extensions[@]} -gt 0 ]; then
        ext_condition="("
        for ext in "${extensions[@]}"; do
            ext_condition+=" -name '*.$ext' -o"
        done
        ext_condition=${ext_condition%-o}
        ext_condition+=" )"
    fi

    while IFS= read -r file; do
        file="${file#./}"
        if [ ${#include_patterns[@]} -eq 0 ] || matches_include_pattern "$file"; then
            if ! should_exclude "$file"; then
                if [ ${#extensions[@]} -eq 0 ] || has_valid_extension "$file"; then
                    print_file_content "$file"
                fi
            fi
        fi
    done < <(eval "$find_cmd -type f $ext_condition")
}

# Main execution
if [ ${#include_patterns[@]} -gt 0 ] || [ ${#extensions[@]} -gt 0 ]; then
    process_files "."
else
    print_usage
fi
