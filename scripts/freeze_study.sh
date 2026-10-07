#!/bin/bash

set -e

# Script for freezing studies

# Help function
show_help() {
    cat << EOF
Usage: freeze_study.sh -s STUDY_DIR -p PROJECT_DIR

Freeze a study by creating a tarball and transferring it to the freeze directory.

ARGUMENTS:
    -s STUDY_DIR      Name of the study directory to freeze
    -p PROJECT_DIR    Name of the project directory containing the study
    -h                Show this help message

DESCRIPTION:
    This script performs the following operations:
    - Checks if the study directory exists
    - Creates a tarball of the study directory
    - Verifies the tarball integrity
    - Transfers the archive to the freeze directory (FREEZE_DIR)
    - Verifies checksums before and after transfer
    - Removes the original study directory and associated active data
    - Logs the freezing operation

    The study can be restored later using the thaw_study.sh script.

EXAMPLE:
    freeze_study.sh -s study_mydata_20231120 -p myproject

EOF
}

# Define flags
while getopts ":hs:p:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        s)
            study_dir="$OPTARG"
            ;;
        p)
            proj_name="$OPTARG"
            ;;
        :)
            printf "Option -%s requires an argument.\n" "$OPTARG" >&2
            exit 1
            ;;
        \?)
            printf "Invalid option: -%s\n" "$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Check for missing flags
if [[ -z "$proj_name" ]]; then
    printf "Error: Missing required argument -p (project directory name).\n" >&2
    exit 1
fi

if [[ -z "$study_dir" ]]; then
    printf "Error: Missing required argument -s (study directory name).\n" >&2
    exit 1
fi

# Get input and set variables
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    printf "Config not found: %s\n" "$CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"

me=$(/usr/bin/whoami)
proj_fullpath="${PROJ_DIR}/${proj_name}"
fullpath="${PROJ_DIR}/${proj_name}/${study_dir}"

# Checks
## Check if dirs exist
if [[ ! -d "$proj_fullpath" ]]; then
    printf "Supplied project directory does not exist.\n" >&2
    exit 1
fi

if [[ ! -d "$fullpath" ]]; then
    printf "Supplied study directory does not exist.\n" >&2
    exit 1
fi

## Check if study exists in freezer
if [[ -f "${FREEZE_DIR}/${study_dir}.tar.gz" ]]; then
    printf "Study already frozen. Please verify name of the study.\n" >&2
    exit 1
fi

# Create study tarball
printf "All checks passed, creating tarball and freezing...\n"
printf "Frozen by %s on %s\n" "$me" "$(/usr/bin/date)" >> "${fullpath}/freeze_log.txt"

cd "$proj_fullpath"
/usr/bin/tar -czf "${study_dir}.tar.gz" "$study_dir"

# Verify tarball archive
printf "Verifying archive...\n"
if /usr/bin/tar -tzf "${study_dir}.tar.gz" > /dev/null; then
    printf "Archive verification successful!\n"
else
    printf "Error: Archive verification failed. Deleting corrupt archive.\n" >&2
    /usr/bin/rm -f "${study_dir:?}.tar.gz"
    exit 1
fi

# Get checksum of archive
printf "Creating checksum of archive...\n"
hash_pre=$(/usr/bin/sha512sum "${study_dir}.tar.gz" | /usr/bin/awk '{print $1}')

# Transfer tarball to storage
printf "Moving archive to freeze directory...\n"

rsync_err_file="$("/usr/bin/mktemp")"

if /usr/bin/rsync -avPW "${study_dir}.tar.gz" "$FREEZE_DIR" 2> "$rsync_err_file"; then
    rm -f "${rsync_err_file:?}"
else
    status=$?
    printf "rsync failed with exit code %d\n" "$status" >&2
    printf "rsync error output:\n" >&2
    /usr/bin/cat "$rsync_err_file" >&2
    /usr/bin/rm -f "${rsync_err_file:?}"
    /usr/bin/rm -f "${study_dir:?}.tar.gz"
    exit "$status"
fi

# Check tarball checksum after transfer
printf "Verifying checksum after transfer...\n"
hash_post=$(/usr/bin/sha512sum "${FREEZE_DIR}/${study_dir}.tar.gz" | /usr/bin/awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    printf "Checksums are equal!\n"
else
    printf "Error: Checksums not equal. Please check files manually.\n" >&2
    /usr/bin/rm -f "${FREEZE_DIR:?}/${study_dir}.tar.gz"
    exit 1
fi

# Log the freezing and cleanup
printf "Logging the freezing and cleaning up files...\n"
printf "%s frozen by %s on %s\n" "$study_dir" "$me" "$(/usr/bin/date)" >> "${proj_fullpath}/freeze_log.txt"
printf "%s\t%s\t%s\t%s\n" "$PROJ_DIR" "$study_dir" "$me" "$(/usr/bin/date)" >> "${FREEZE_DIR}/freeze_log.txt"
/usr/bin/rm -rf "${fullpath:?}"
/usr/bin/rm -f "${fullpath:?}.tar.gz"
/usr/bin/rm -rf "${ACTIVE_DATA_DIR:?}/${study_dir##study_}"

printf "Freezing complete!\n"
