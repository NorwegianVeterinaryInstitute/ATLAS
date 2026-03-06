#!/bin/bash

set -e

# Script for archiving studies.
# The script will create a tarball of the
# study directory, and transfer the
# tarball to the correct location on NIRD.

# Help function
show_help() {
    cat << EOF
Usage: archive_study.sh -s STUDY_DIR -p PROJECT_DIR

Archive a study by creating a tarball and transferring it to NIRD storage.

ARGUMENTS:
    -s STUDY_DIR      Name of the study directory to archive
    -p PROJECT_DIR    Name of the project directory containing the study
    -h                Show this help message

DESCRIPTION:
    This script performs the following operations:
    - Checks if the study directory exists and meets requirements
    - Warns if directory size exceeds 250GB
    - Verifies that sandbox directory has been removed
    - Verifies that results and data directories are present
    - Creates a tarball of the study directory
    - Verifies the tarball integrity
    - Transfers the archive to NIRD (/nird/datalake/NS9305K/study_archive)
    - Verifies checksums before and after transfer
    - Removes the original study and data directories after successful archiving
    - Logs the archiving operation

REQUIREMENTS:
    - Sandbox directory must be removed before archiving
    - Results directory must be present
    - Data directory must be present

EXAMPLE:
    archive_study.sh -s study_mydata_20231120 -p myproject

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
if [[ -z "$study_dir" ]]; then
    echo "Error: Missing required argument -s (study directory name)." >&2
    exit 1
fi

if [[ -z "$proj_name" ]]; then
    echo "Error: Missing required argument -p (project directory name)." >&2
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

## Prompt user for archive process confirmation
echo "You are about to archive the study '$study_dir' from project '$proj_name' to ${ARCHIVE_DIR}."
read -r -p "Start the archiving process? (y/n): " response
if [[ "$response" != "y" && "$response" != "Y" ]]; then
    echo "Archiving cancelled."
    exit 1
fi

## Check directory size
size_kb=$(du -s "$fullpath" | awk '{print $1}')
size_mb=$((size_kb / 1024))
size_gb=$((size_mb / 1024))

threshold="${ARCHIVE_SIZE_THRESHOLD_GB:-250}"

if (( size_gb > threshold )); then
    echo "Warning: Experiment directory '$study_dir' is very large (~${size_gb}GB)."
    echo "Please consider removing additional redundant or intermediary files."
    read -r -p "Continue archiving anyway? (y/n): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        echo "Archiving cancelled."
        exit 1
    fi
fi

# Check for presence of specific directories
## Check if sandbox archive is removed
if [[ -d "$fullpath/sandbox" ]]; then
    echo "The sandbox directory is still present in the study."
    echo "Please delete it before archiving."
    exit 1
fi

if [[ ! -d "$fullpath/results" ]]; then
    echo "The results directory is not present in the study."
    echo "Please make sure to uphold the directory structure of studies."
    echo "Stopping the archiving process."
    exit 1
fi

if [[ ! -d "$fullpath/data" ]]; then
    echo "The data directory is not present in the study."
    echo "Please make sure to uphold the directory structure of studies."
    echo "Stopping the archiving process."
    exit 1
fi

## Check if experiment exists in the archive
if [[ -d "${ARCHIVE_DIR}/${study_dir}.tar.gz" ]]; then
    echo "Study already archived. Please verify name of the study."
    exit 1
fi

# Create experiment tarball
echo "All checks passed, creating tarball..."
tar -czf "${fullpath}.tar.gz" "$fullpath"

# Verify tarball archive
echo "Verifying archive..."
if tar -tzf "${fullpath}.tar.gz" > /dev/null; then
    echo "Archive verification successful!"
else
    echo "Error: Archive verification failed. Deleting corrupt archive."
    rm -f "${fullpath}.tar.gz"
    exit 1
fi

# Get checksum of archive
echo "Creating checksum of archive..."
hash_pre="$(sha512sum "${fullpath}.tar.gz" | awk '{print $1}')"

# Transfer tarball to storage
echo "Moving archive to NIRD..."
rsync_err_file="$(mktemp)"

if rsync -avPW "${fullpath}.tar.gz" "$ARCHIVE_DIR" 2> "$rsync_err_file"; then
    rm -f "$rsync_err_file"
else
    status=$?
    echo "rsync failed with exit code $status" >&2
    echo "rsync error output:" >&2
    cat "$rsync_err_file" >&2
    rm -f "$rsync_err_file"
    exit "$status"
fi

# Check tarball checksum after transfer
echo "Verifying checksum after transfer..."
hash_post="$(sha512sum "${ARCHIVE_DIR}/${study_dir}.tar.gz" | awk '{print $1}')"

if [[ "$hash_pre" == "$hash_post" ]]; then
    echo "Checksums are equal, transfer complete!"
else
    echo "Error: Checksums not equal. Please check files manually."
    rm -f "${ARCHIVE_DIR:?}/${study_dir}.tar.gz"
    exit 1
fi

# Cleanup and logging
echo "Performing cleanup..."
chmod 444 "${ARCHIVE_DIR:?}/${study_dir}.tar.gz"
rm -f "${fullpath:?}.tar.gz"
rm -rf "${fullpath:?}"
rm -rf "${ACTIVE_DATA_DIR:?}/${study_dir##study_}"

echo "Logging the transfer..."
me=$(whoami)
echo "$study_dir archived by $me on $(date)" >> "${proj_fullpath}/archive_log.txt"
echo -e "$proj_name\t$study_dir\t$me\t$(date)" >> "${ARCHIVE_DIR}/archive_log.txt"

echo "Archiving complete!"
