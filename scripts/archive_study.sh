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
            /usr/bin/printf "Option -%s requires an argument.\n" "$OPTARG" >&2
            exit 1
            ;;
        \?)
            /usr/bin/printf "Invalid option: -%s\n" "$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Check for missing flags
if [[ -z "$study_dir" ]]; then
    /usr/bin/printf "Error: Missing required argument -s (study directory name).\n" >&2
    exit 1
fi

if [[ -z "$proj_name" ]]; then
    /usr/bin/printf "Error: Missing required argument -p (project directory name).\n" >&2
    exit 1
fi

# Get input and set variables
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    /usr/bin/printf "Config not found: %s\n" "$CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"

proj_fullpath="${PROJ_DIR}/${proj_name}"
fullpath="${PROJ_DIR}/${proj_name}/${study_dir}"

# Checks
## Check if dirs exist
if [[ ! -d "$proj_fullpath" ]]; then
    /usr/bin/printf "Supplied project directory does not exist.\n" >&2
    exit 1
fi

if [[ ! -d "$fullpath" ]]; then
    /usr/bin/printf "Supplied study directory does not exist.\n" >&2
    exit 1
fi

## Prompt user for archive process confirmation
/usr/bin/printf "You are about to archive the study '%s' from project '%s' to %s.\n" "$study_dir" "$proj_name" "$ARCHIVE_DIR"
read -r -p "Start the archiving process? (y/n): " response
if [[ "$response" != "y" && "$response" != "Y" ]]; then
    /usr/bin/printf "Archiving cancelled.\n"
    exit 1
fi

## Check directory size
size_kb=$(/usr/bin/du -s "$fullpath" | /usr/bin/awk '{print $1}')
size_mb=$((size_kb / 1024))
size_gb=$((size_mb / 1024))

threshold="${ARCHIVE_SIZE_THRESHOLD_GB:-250}"

if (( size_gb > threshold )); then
    /usr/bin/printf "Warning: Experiment directory '%s' is very large (~%dGB).\n" "$study_dir" "$size_gb"
    /usr/bin/printf "Please consider removing additional redundant or intermediary files.\n"
    read -r -p "Continue archiving anyway? (y/n): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        /usr/bin/printf "Archiving cancelled.\n"
        exit 1
    fi
fi

# Check for presence of specific directories
## Check if sandbox archive is removed
if [[ -d "$fullpath/sandbox" ]]; then
    /usr/bin/printf "The sandbox directory is still present in the study.\n"
    /usr/bin/printf "Please delete it before archiving.\n"
    exit 1
fi

if [[ ! -d "$fullpath/results" ]]; then
    /usr/bin/printf "The results directory is not present in the study.\n"
    /usr/bin/printf "Please make sure to uphold the directory structure of studies.\n"
    /usr/bin/printf "Stopping the archiving process.\n"
    exit 1
fi

if [[ ! -d "$fullpath/data" ]]; then
    /usr/bin/printf "The data directory is not present in the study.\n"
    /usr/bin/printf "Please make sure to uphold the directory structure of studies.\n"
    /usr/bin/printf "Stopping the archiving process.\n"
    exit 1
fi

## Check if experiment exists in the archive
if [[ -f "${ARCHIVE_DIR}/${study_dir}.tar.gz" ]]; then
    /usr/bin/printf "Study already archived. Please verify name of the study.\n"
    exit 1
fi

# Create experiment tarball
/usr/bin/printf "All checks passed, creating tarball...\n"
cd "$proj_fullpath"
/usr/bin/tar -czf "${study_dir}.tar.gz" "$study_dir"

# Verify tarball archive
/usr/bin/printf "Verifying archive...\n"
if /usr/bin/tar -tzf "${study_dir}.tar.gz" > /dev/null; then
    /usr/bin/printf "Archive verification successful!\n"
else
    /usr/bin/printf "Error: Archive verification failed. Deleting corrupt archive.\n"
    /usr/bin/rm -f "${study_dir}.tar.gz"
    exit 1
fi

# Get checksum of archive
/usr/bin/printf "Creating checksum of archive...\n"
hash_pre="$(/usr/bin/sha512sum "${study_dir}.tar.gz" | awk '{print $1}')"

# Transfer tarball to storage
/usr/bin/printf "Moving archive to NIRD...\n"
rsync_err_file="$("/usr/bin/mktemp")"

if /usr/bin/rsync -avPW "${study_dir}.tar.gz" "$ARCHIVE_DIR" 2> "$rsync_err_file"; then
    /usr/bin/rm -f "${rsync_err_file:?}"
else
    status=$?
    /usr/bin/printf "rsync failed with exit code %d\n" "$status" >&2
    /usr/bin/printf "rsync error output:\n" >&2
    /usr/bin/cat "$rsync_err_file" >&2
    /usr/bin/rm -f "${rsync_err_file:?}"
    /usr/bin/rm -f "${study_dir:?}.tar.gz"
    exit "$status"
fi

# Check tarball checksum after transfer
/usr/bin/printf "Verifying checksum after transfer...\n"
hash_post="$(/usr/bin/sha512sum "${ARCHIVE_DIR}/${study_dir}.tar.gz" | /usr/bin/awk '{print $1}')"

if [[ "$hash_pre" == "$hash_post" ]]; then
    /usr/bin/printf "Checksums are equal, transfer complete!\n"
else
    /usr/bin/printf "Error: Checksums not equal. Please check files manually.\n"
    /usr/bin/rm -f "${ARCHIVE_DIR:?}/${study_dir}.tar.gz"
    exit 1
fi

# Cleanup and logging
/usr/bin/printf "Performing cleanup...\n"
chmod 444 "${ARCHIVE_DIR:?}/${study_dir}.tar.gz"
/usr/bin/rm -f "${study_dir:?}.tar.gz"
/usr/bin/rm -rf "${study_dir:?}"
/usr/bin/rm -rf "${ACTIVE_DATA_DIR:?}/${study_dir##study_}"

/usr/bin/printf "Logging the transfer...\n"
me=$(/usr/bin/whoami)
/usr/bin/printf "%s archived by %s on %s\n" "$study_dir" "$me" "$(/usr/bin/date)" >> "${proj_fullpath}/archive_log.txt"
/usr/bin/printf "%s\t%s\t%s\t%s\n" "$proj_name" "$study_dir" "$me" "$(/usr/bin/date)" >> "${ARCHIVE_DIR}/archive_log.txt"

/usr/bin/printf "Archiving complete!\n"
