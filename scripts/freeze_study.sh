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
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Check for missing flags
if [[ -z "$proj_name" ]]; then
    echo "Error: Missing required argument -p (project directory name)." >&2
    exit 1
fi

if [[ -z "$study_dir" ]]; then
    echo "Error: Missing required argument -s (study directory name)." >&2
    exit 1
fi

# Get input and set variables
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    echo "Config not found: $CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"

me=$(whoami)
proj_fullpath="${PROJ_DIR}/${proj_name}"
fullpath="${PROJ_DIR}/${proj_name}/${study_dir}"

# Checks
## Check if dirs exist
if [[ ! -d "$proj_fullpath" ]]; then
    echo "Supplied project directory does not exist."
    exit 1
fi

if [[ ! -d "$fullpath" ]]; then
    echo "Supplied study directory does not exist."
    exit 1
fi

## Check if study exists in freezer
if [[ -d "${FREEZE_DIR}/${study_dir}.tar.gz" ]]; then
    echo "Study already frozen. Please verify name of the study."
    exit 1
fi

# Create study tarball
echo "All checks passed, creating tarball and freezing..."
echo "Frozen by $me on $(date)" >> "${fullpath}/stash_log.txt"

cd "$proj_fullpath"
tar -czf "${study_dir}.tar.gz" "$study_dir"

# Verify tarball archive
echo "Verifying archive..."
if tar -tzf "${study_dir}.tar.gz" > /dev/null; then
    echo "Archive verification successful!"
else
    echo "Error: Archive verification failed. Deleting corrupt archive."
    rm -f "${study_dir}.tar.gz"
    exit 1
fi

# Get checksum of archive
echo "Creating checksum of archive..."
hash_pre=$(sha512sum "${study_dir}.tar.gz" | awk '{print $1}')

# Transfer tarball to storage
echo "Moving archive to freeze directory..."

rsync_err_file="$(mktemp)"

if rsync -avPW "${study_dir}.tar.gz" "$FREEZE_DIR" 2> "$rsync_err_file"; then
    rm -f "${rsync_err_file:?}"
else
    status=$?
    echo "rsync failed with exit code $status" >&2
    echo "rsync error output:" >&2
    cat "$rsync_err_file" >&2
    rm -f "${rsync_err_file:?}"
    exit "$status"
fi

# Check tarball checksum after transfer
echo "Verifying checksum after transfer..."
hash_post=$(sha512sum "${FREEZE_DIR}/${study_dir}.tar.gz" | awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    echo "Checksums are equal!"
else
    echo "Error: Checksums not equal. Please check files manually."
    rm -f "${FREEZE_DIR:?}/${study_dir}.tar.gz"
    exit 1
fi

# Log the freezing and cleanup
echo "Logging the freezing and cleaning up files..."
echo "$study_dir frozen by $me on $(date)" >> "${proj_fullpath}/freeze_log.txt"
echo -e "$PROJ_DIR\t$study_dir\t$me\t$(date)" >> "${FREEZE_DIR}/freeze_log.txt"
rm -rf "${fullpath:?}"
rm -f "${fullpath:?}.tar.gz"
rm -rf "${ACTIVE_DATA_DIR:?}/${study_dir##study_}"

echo "Freezing complete!"
