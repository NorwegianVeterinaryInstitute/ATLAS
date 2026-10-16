#!/bin/bash

# Script used to check that the external tools called by the ATLAS
# scripts are installed in the expected location and version.
# Uses only bash builtins for its own work, so it runs even when
# the tools it checks for are missing.

# Help function
show_help() {
    printf '%s\n' \
        "Usage: check_dependencies.sh" \
        "" \
        "Check that the external tools used by the ATLAS scripts are installed." \
        "" \
        "ARGUMENTS:" \
        "    -h                Show this help message" \
        "" \
        "DESCRIPTION:" \
        "    This script:" \
        "    - Reads the ATLAS scripts and lists every tool they call by absolute path" \
        "    - Checks that each of these tools exists and is executable" \
        "    - Checks that gzip is on PATH (tar starts it by name)" \
        "    - Checks minimum versions of rsync, sha512sum and dos2unix" \
        "    - Exits with an error if any tool is missing or too old" \
        "" \
        "EXAMPLE:" \
        "    check_dependencies.sh" \
        ""
}

# Checks
## Check for help flag
while getopts ":h" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        \?)
            printf "Invalid option: -%s\n" "$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Minimum versions of tools
declare -A MIN_VERSION=(
    [rsync]="3.2.5"
    [sha512sum]="8.32"
    [dos2unix]="7.4.2"
)

# Functions
## Return success if version $1 is at least version $2
version_at_least() {
    local -a have want
    local i h w
    IFS=. read -ra have <<< "$1"
    IFS=. read -ra want <<< "$2"
    for i in "${!want[@]}"; do
        h=$((10#${have[i]:-0}))
        w=$((10#${want[i]}))
        ((h > w)) && return 0
        ((h < w)) && return 1
    done
    return 0
}

## Print the first version number in the --version output of tool $1
tool_version() {
    local line
    read -r line < <("$1" --version 2>&1)
    [[ "$line" =~ ([0-9]+(\.[0-9]+)+) ]] && printf "%s" "${BASH_REMATCH[1]}"
}

## Check tool at path $1, print its status and return failure on a problem
check_tool() {
    local path="$1"
    local name="${path##*/}"
    local version

    if [[ ! -x "$path" ]]; then
        printf "  %-8s %s\n" "missing" "$path"
        return 1
    fi

    if [[ -n "${MIN_VERSION[$name]}" ]]; then
        version="$(tool_version "$path")"
        if [[ -z "$version" ]] || ! version_at_least "$version" "${MIN_VERSION[$name]}"; then
            printf "  %-8s %s (%s, need >= %s)\n" "too old" "$path" "${version:-unknown version}" "${MIN_VERSION[$name]}"
            return 1
        fi
        printf "  %-8s %s (%s)\n" "ok" "$path" "$version"
        return 0
    fi

    printf "  %-8s %s\n" "ok" "$path"
}

# Get input and set variables
## Get script dir, following a link from a bin directory if possible
if [[ -x /usr/bin/readlink ]]; then
    script_path="$(/usr/bin/readlink -f -- "${BASH_SOURCE[0]}")"
else
    script_path="${BASH_SOURCE[0]}"
fi
if [[ "$script_path" == */* ]]; then
    SCRIPT_DIR="${script_path%/*}"
else
    SCRIPT_DIR="."
fi

## Collect tools called by absolute path, in order of first use
declare -A seen=()
tools=()
for script in "$SCRIPT_DIR"/*.sh; do
    while IFS= read -r line || [[ -n "$line" ]]; do
        while [[ "$line" =~ /usr/bin/([A-Za-z0-9._+-]+) ]]; do
            tool="${BASH_REMATCH[0]}"
            if [[ -z "${seen[$tool]}" ]]; then
                seen[$tool]=1
                tools+=("$tool")
            fi
            line="${line#*"$tool"}"
        done
    done < "$script"
done

if [[ ${#tools[@]} -eq 0 ]]; then
    printf "Error: No tools found in scripts in %s.\n" "$SCRIPT_DIR" >&2
    exit 1
fi

# Check tools
problems=0

printf "Tools called by absolute path:\n"
for tool in "${tools[@]}"; do
    check_tool "$tool" || problems=$((problems + 1))
done

printf "Tools found through PATH:\n"
if gzip_path="$(command -v gzip)"; then
    printf "  %-8s gzip (%s)\n" "ok" "$gzip_path"
else
    printf "  %-8s gzip\n" "missing"
    problems=$((problems + 1))
fi

if ((problems > 0)); then
    printf "Error: %d tool(s) missing or too old.\n" "$problems" >&2
    exit 1
fi

printf "All %d tools found.\n" $((${#tools[@]} + 1))
