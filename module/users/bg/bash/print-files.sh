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
    echo "Usage: $0 [-i pattern ...] [-t ext1,ext2,...] [-e pattern ...] [--keep-comments] [-r] [-n] [-c command] [-g] [-G] [-s]"
    echo "Example: $0 -i '*.go' -i '*_test.go' -t nix,txt,md -e '*_name.go' -e '.log' -r -n"
    echo "Use -i to specify files/patterns to include"
    echo "Use -t to specify file extensions to include"
    echo "Use -e to specify patterns to exclude"
    echo "Use -k to preserve comments in the output"
    echo "Use -r for recursive search"
    echo "Use -n to show line numbers"
    echo "Use -c 'command' to use output of command as source of files (e.g. -c \"rg -l 'pattern'\")"
    echo "Use -g to include git modified files (working directory changes)"
    echo "Use -G to include all git changes from HEAD (staged + modified)"
    echo "Use -s to include git staged files only"
    echo "Git options filter to current directory and subdirectories only"
    exit 1
}

include_patterns=()
extensions=()
exclude_patterns=()
keep_comments=false
recursive=false
line_numbers=false
command=""
git_modified=false
git_all_changes=false
git_staged=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                include_patterns+=("$1")
                shift
            done
            ;;
        -t)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                IFS=',' read -ra new_extensions <<<"$1"
                extensions+=("${new_extensions[@]}")
                shift
            done
            ;;
        -e)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                exclude_patterns+=("$1")
                shift
            done
            ;;
        -k)
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
        -c)
            shift
            if [[ $# -gt 0 ]]; then
                command="$1"
                shift
            else
                echo "Error: -c requires a command argument"
                print_usage
            fi
            ;;
        -g)
            git_modified=true
            shift
            ;;
        -G)
            git_all_changes=true
            shift
            ;;
        -s)
            git_staged=true
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
        local abs_file
        if [[ "$file" = /* ]]; then
            abs_file="$file"
        else
            abs_file="$(pwd)/$file"
        fi
        if [[ "$pattern" == *"/"* ]]; then
            local full_pattern
            if [[ "$pattern" = /* ]]; then
                full_pattern="$pattern"
            else
                full_pattern="$(pwd)/$pattern"
            fi
            if [[ "$abs_file" == $full_pattern ]] || [[ "$abs_file" == *"/$pattern" ]]; then
                return 0
            fi
        else
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
        if [[ "$pattern" == *"/"* ]]; then
            if [[ "$filepath" == $pattern ]] || [[ "$filepath" == *"/$pattern" ]]; then
                return 0
            fi
        else
            local basename_file
            basename_file=$(basename "$filepath")
            if [[ "$basename_file" == $pattern ]]; then
                return 0
            fi
        fi
    done
    return 1
}

process_git_files() {
    local git_cmd=""

    if [ "$git_staged" = true ]; then
        git_cmd="git diff --cached --name-only"
    elif [ "$git_all_changes" = true ]; then
        git_cmd="git diff --name-only HEAD"
    elif [ "$git_modified" = true ]; then
        git_cmd="git diff --name-only"
    else
        return 1
    fi

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not in a git repository"
        exit 1
    fi

    # Получаем git root и текущую директорию
    local git_root
    git_root="$(git rev-parse --show-toplevel)"
    local current_dir="$(pwd)"

    # Вычисляем относительный путь от git root до текущей директории
    local current_rel_path=""
    if [[ "$current_dir" != "$git_root" ]]; then
        current_rel_path="${current_dir#$git_root/}"
    fi

    while IFS= read -r git_file; do
        if [[ -z "$git_file" ]]; then
            continue
        fi

        # Если мы не в корне git репозитория, фильтруем файлы по текущей поддиректории
        if [[ -n "$current_rel_path" ]]; then
            # Проверяем, что файл находится в нашей поддиректории
            if [[ "$git_file" != "$current_rel_path"* ]]; then
                continue
            fi
        fi

        # Полный путь к файлу
        local full_file_path="$git_root/$git_file"

        # Проверяем существование файла
        if [[ ! -f "$full_file_path" ]]; then
            continue
        fi

        # Вычисляем относительный путь от текущей директории
        local relative_file
        if [[ -n "$current_rel_path" ]]; then
            # Убираем префикс текущей директории из пути файла
            relative_file="${git_file#$current_rel_path/}"
        else
            relative_file="$git_file"
        fi

        # Применяем фильтры
        if ! should_exclude "$relative_file"; then
            if [ ${#extensions[@]} -eq 0 ] || has_valid_extension "$relative_file"; then
                if [ ${#include_patterns[@]} -eq 0 ] || matches_include_pattern "$relative_file"; then
                    # Используем относительный путь для вывода, но полный для чтения
                    print_file_content "$full_file_path"
                fi
            fi
        fi
    done < <(eval "$git_cmd" 2>/dev/null)
}

process_command_output() {
    local cmd="$1"
    while IFS= read -r file; do
        if ! should_exclude "$file"; then
            if [ ${#extensions[@]} -eq 0 ] || has_valid_extension "$file"; then
                print_file_content "$file"
            fi
        fi
    done < <(eval "$cmd")
}

process_files() {
    local has_path_pattern=false
    local search_roots=(".")

    for pattern in "${include_patterns[@]}"; do
        if [[ "$pattern" == *"/"* ]]; then
            has_path_pattern=true
            local dir=$(dirname "$pattern")
            if [[ ! " ${search_roots[@]} " =~ " ${dir} " ]]; then
                search_roots+=("$dir")
            fi
        fi
    done

    if [ "$has_path_pattern" = false ]; then
        search_roots=(".")
    fi

    for search_root in "${search_roots[@]}"; do
        local find_cmd="find"
        if [ "$recursive" = true ]; then
            find_cmd="find $search_root"
        else
            find_cmd="find $search_root -maxdepth 1"
        fi

        local ext_condition=""
        if [ ${#extensions[@]} -gt 0 ]; then
            for ext in "${extensions[@]}"; do
                ext_condition+=" -name '*.$ext' -o"
            done
            ext_condition=${ext_condition%-o}
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
    done
}

# Основная логика выполнения
if [ "$git_modified" = true ] || [ "$git_all_changes" = true ] || [ "$git_staged" = true ]; then
    process_git_files
elif [ -n "$command" ]; then
    process_command_output "$command"
elif [ ${#include_patterns[@]} -gt 0 ] || [ ${#extensions[@]} -gt 0 ]; then
    process_files "."
else
    print_usage
fi
