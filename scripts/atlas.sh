#!/bin/bash

# Single entry point for the ATLAS scripts: "atlas COMMAND [ARGS]"
# runs COMMAND.sh from the same directory with ARGS.

# Help function
show_help() {
    cat << 'EOF'
Usage: atlas COMMAND [ARGS]
       atlas.sh COMMAND [ARGS]

Run an ATLAS command. Link this script into a bin directory as "atlas"
to call it as: atlas COMMAND [ARGS]

COMMANDS:
    create_project       Create a project directory in PROJ_DIR
    activate_data        Activate data from tarball storage into ACTIVE_DATA_DIR
    create_study         Create a study directory in a project
    freeze_study         Freeze a study to FREEZE_DIR
    thaw_study           Thaw a frozen study back into its project
    archive_study        Archive a finished study to ARCHIVE_DIR
    check_dependencies   Check that the external tools ATLAS uses are installed

ARGUMENTS:
    -h                   Show this help message
    COMMAND -h           Show the help message of COMMAND

EXAMPLE:
    atlas create_project -p 12345_MyProject
    atlas freeze_study -h

EOF
}

# Get script dir, following a link from a bin directory if possible
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

command="${1:-}"
case "$command" in
    create_project|activate_data|create_study|freeze_study|thaw_study|archive_study|check_dependencies)
        shift
        exec "$BASH" "${SCRIPT_DIR}/${command}.sh" "$@"
        ;;
    -h|--help|help)
        show_help
        exit 0
        ;;
    "")
        show_help >&2
        exit 1
        ;;
    *)
        printf "Unknown command: %s\n" "$command" >&2
        printf "Run 'atlas -h' for a list of commands.\n" >&2
        exit 1
        ;;
esac
