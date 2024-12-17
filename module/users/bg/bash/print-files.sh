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
    echo "Usage: $0 [-i pattern ...] [-t ext1,ext2,...] [-e pattern ...] [--keep-comments] [-r] [-n] [-c command]"
    echo "Example: $0 -i '*.go' -i '*_test.go' -t nix,txt,md -e '*_name.go' -e '.log' -r -n"
    echo "Use -i to specify files/patterns to include"
    echo "Use -t to specify file extensions to include"
    echo "Use -e to specify patterns to exclude"
    echo "Use -k to preserve comments in the output"
    echo "Use -r for recursive search"
    echo "Use -n to show line numbers"
    echo "Use -c 'command' to use output of command as source of files (e.g. -c \"rg -l 'pattern'\")"
    exit 1
}

include_patterns=()
extensions=()
exclude_patterns=()
keep_comments=false
recursive=false
line_numbers=false
command=""

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
            command="$2"
            shift 2
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
    done
}

if [ -n "$command" ]; then
    process_command_output "$command"
elif [ ${#include_patterns[@]} -gt 0 ] || [ ${#extensions[@]} -gt 0 ]; then
    process_files "."
else
    print_usage
fi
