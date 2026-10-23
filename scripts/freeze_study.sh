#!/bin/bash

set -eo pipefail

# Script for freezing studies

# Help function
show_help() {
    cat << EOF
Usage: freeze_study.sh -s STUDY_DIR -p PROJECT_DIR [-y]

Freeze a study by creating a tarball and transferring it to FREEZE_DIR.

ARGUMENTS:
    -s STUDY_DIR      Name of the study directory to freeze
    -p PROJECT_DIR    Name of the project directory containing the study
    -y                Do not ask for confirmation (for scripted use)
    -h                Show this help message

DESCRIPTION:
    This script performs the following operations:
    - Checks if the study directory and FREEZE_DIR exist
    - Checks that the source tarballs in the study's data.csv still exist
    - Asks for confirmation, unless -y is given
    - Creates a tarball of the study directory
    - Verifies the tarball integrity
    - Transfers the archive to the freeze directory (FREEZE_DIR)
    - Verifies checksums before and after transfer
    - Removes the original study directory and associated active data
    - Logs the freezing operation

    The study can be restored later using the thaw_study.sh script.

    The frozen study holds links to the reads, not the reads themselves.
    Thawing extracts the reads again from the source tarballs listed in
    data.csv, so those must stay where they are.

EXAMPLE:
    freeze_study.sh -s study_mydata_20231120 -p myproject

EOF
}

# Define flags
assume_yes=false

while getopts ":hys:p:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        y)
            assume_yes=true
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
## Get script dir
SCRIPT_DIR="$(cd -- "$(/usr/bin/dirname -- "$(/usr/bin/readlink -f -- "${BASH_SOURCE[0]}")")" && pwd -P)"
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    printf "Config not found: %s\n" "$CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

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

## Without this check, rsync would create a file named after the directory
if [[ ! -d "$FREEZE_DIR" ]]; then
    printf "Freeze directory does not exist: %s\n" "$FREEZE_DIR" >&2
    exit 1
fi

## Check if study exists in freezer
if [[ -f "${FREEZE_DIR}/${study_dir}.tar.gz" ]]; then
    printf "Study already frozen. Please verify name of the study.\n" >&2
    exit 1
fi

## Thawing extracts the reads again from the source tarballs
if [[ ! -f "${fullpath}/data.csv" ]]; then
    printf "Error: %s not found; cannot check the source tarballs.\n" "${fullpath}/data.csv" >&2
    exit 1
fi
if ! check_tarballs "${fullpath}/data.csv" false; then
    printf "Thawing needs the source tarballs. Not freezing.\n" >&2
    exit 1
fi

## Prompt user for freeze confirmation
if ! $assume_yes; then
    printf "You are about to freeze the study '%s' from project '%s' to %s.\n" "$study_dir" "$proj_name" "$FREEZE_DIR"
    printf "The study and its active data will be deleted afterwards.\n"
    read -r -p "Start the freezing process? (y/n): " response || true
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        printf "Freezing cancelled.\n"
        exit 1
    fi
fi

# Create study tarball
printf "All checks passed, creating tarball and freezing...\n"
## The entry ends up in the tarball. If the freeze fails, take it out again.
freeze_log="${fullpath}/freeze_log.txt"
had_freeze_log=false
if [[ -f "$freeze_log" ]]; then
    had_freeze_log=true
fi
undo_freeze_log() {
    if $had_freeze_log; then
        /usr/bin/sed -i '$d' "$freeze_log"
    else
        /usr/bin/rm -f "$freeze_log"
    fi
}
printf "Frozen by %s on %s\n" "$me" "$(/usr/bin/date)" >> "$freeze_log"
trap undo_freeze_log EXIT

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

if /usr/bin/rsync -avPW "${study_dir}.tar.gz" "${FREEZE_DIR}/" 2> "$rsync_err_file"; then
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
## A failed hash counts as a mismatch, so the copy is removed below
if ! hash_post=$(/usr/bin/sha512sum "${FREEZE_DIR}/${study_dir}.tar.gz" | /usr/bin/awk '{print $1}'); then
    hash_post=""
fi

if [[ "$hash_pre" == "$hash_post" ]]; then
    printf "Checksums are equal!\n"
else
    printf "Error: Checksums not equal. Please check files manually.\n" >&2
    /usr/bin/rm -f "${FREEZE_DIR:?}/${study_dir}.tar.gz"
    exit 1
fi

# Log the freezing and cleanup
trap - EXIT
printf "Logging the freezing and cleaning up files...\n"
printf "%s frozen by %s on %s\n" "$study_dir" "$me" "$(/usr/bin/date)" >> "${proj_fullpath}/freeze_log.txt"
printf "%s\t%s\t%s\t%s\n" "$proj_name" "$study_dir" "$me" "$(/usr/bin/date)" >> "${FREEZE_DIR}/freeze_log.txt"
/usr/bin/rm -rf "${fullpath:?}"
/usr/bin/rm -f "${fullpath:?}.tar.gz"
/usr/bin/rm -rf "${ACTIVE_DATA_DIR:?}/${study_dir##study_}"

printf "Freezing complete!\n"
