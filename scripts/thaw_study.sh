#!/bin/bash

set -e

# Script for thawing studies

# Help function
show_help() {
    cat << EOF
Usage: thaw_study.sh -s STUDY_DIR -p PROJECT_DIR

Thaw (restore) a frozen study from freezer storage.

ARGUMENTS:
    -s STUDY_DIR      Name of the study directory to thaw
    -p PROJECT_DIR    Name of the project directory to restore the study to
    -h                Show this help message

DESCRIPTION:
    This script performs the following operations:
    - Retrieves a frozen study from the freeze directory (FREEZE_DIR)
    - Verifies checksums before and after transfer
    - Unpacks the tarball to restore the study directory
    - Reconstitutes the study data using activate_data.sh
    - Verifies sha512sums of the restored data
    - Removes the tarball from freezer after successful restoration
    - Logs the thawing operation

    This script is used to restore studies that were previously frozen
    using the freeze_study.sh script.

EXAMPLE:
    thaw_study.sh -s study_mydata_20231120 -p myproject

EOF
}

# Get script dir
SCRIPT_DIR="$(cd -- "$(/usr/bin/dirname -- "$(/usr/bin/readlink -f -- "${BASH_SOURCE[0]}")")" && pwd -P)"

# Define flags
while getopts ":hp:s:" opt; do
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

me=$(/usr/bin/whoami)
proj_fullpath="${PROJ_DIR}/${proj_name}"
fullpath="${PROJ_DIR}/${proj_name}/${study_dir}"

# Checks
## Check if dirs exist
if [[ ! -d "$proj_fullpath" ]]; then
    /usr/bin/printf "Supplied project directory does not exist.\n" >&2
    exit 1
fi

## Check if study exists in freezer
if [[ -d "$fullpath" ]]; then
    /usr/bin/printf "Study already thawed. Please verify name of the study.\n" >&2
    exit 1
fi

# Thaw study
/usr/bin/printf "All checks passed, creating tarball and thawing...\n"
/usr/bin/printf "Thawing tarball and transferring to Saga...\n"

## Get checksum before transfer
hash_pre=$(/usr/bin/sha512sum "${FREEZE_DIR}/${study_dir}.tar.gz" | /usr/bin/awk '{print $1}')

## Transfer file
rsync_err_file="$("/usr/bin/mktemp")"

if /usr/bin/rsync -avPW "${FREEZE_DIR}/${study_dir}.tar.gz" "$proj_fullpath" 2> "$rsync_err_file"; then
    /usr/bin/rm -f "${rsync_err_file:?}"
else
    status=$?
    /usr/bin/printf "rsync failed with exit code %d\n" "$status" >&2
    /usr/bin/printf "rsync error output:\n" >&2
    /usr/bin/cat "$rsync_err_file" >&2
    /usr/bin/rm -f "${rsync_err_file:?}"
    exit "$status"
fi

## Verify checksum
/usr/bin/printf "Verifying checksum after transfer...\n"
hash_post=$(/usr/bin/sha512sum "${fullpath}.tar.gz" | /usr/bin/awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    /usr/bin/printf "Checksums are equal, transfer complete!\n"
else
    /usr/bin/printf "Error: Checksums not equal. Please check files manually.\n" >&2
    /usr/bin/rm -f "${fullpath:?}.tar.gz"
    exit 1
fi

## Unpack tarball
/usr/bin/printf "Unpacking study...\n"
cd "$proj_fullpath"
/usr/bin/tar -xzf "${study_dir}.tar.gz"
/usr/bin/printf "Thawed by %s on %s\n" "$me" "$(/usr/bin/date)" >> "${study_dir}/freeze_log.txt"
/usr/bin/printf "%s thawed by %s on %s\n" "$study_dir" "$me" "$(/usr/bin/date)" >> "${proj_fullpath}/freeze_log.txt"

## Cleanup
/usr/bin/rm -f "${FREEZE_DIR:?}/${study_dir}.tar.gz"
/usr/bin/rm -f "${study_dir:?}.tar.gz"
/usr/bin/printf "%s\t%s\t%s\t%s\n" "$proj_name" "$study_dir" "$me" "$(/usr/bin/date)" >> "${FREEZE_DIR}/thaw_log.txt"

# Reconstitute study data
/usr/bin/printf "Reconstituting study data...\n"
(/usr/bin/bash "${SCRIPT_DIR}/activate_data.sh" -c "${fullpath}/data.csv" -d "${study_dir##study_}")

/usr/bin/printf "Comparing sha512sums...\n"
test=$( /usr/bin/grep -Fxvf "${ACTIVE_DATA_DIR}/${study_dir##study_}/sha512sums.txt" "${fullpath}/sha512sums.txt" || true )

if [[ ! -z "${test}" ]]; then
    /usr/bin/printf "sha512sums not equal, please check the following reads:\n"
    /usr/bin/printf "%s\n" "$test"
    exit 1
else
    /usr/bin/printf "sha512sum equal, thawing done!\n"
fi