#!/bin/bash

set -e

# Script for thawing studies

# Help function
show_help() {
    cat << EOF
Usage: thaw_study.sh STUDY_DIR PROJECT_DIR

Thaw (restore) a frozen study from freezer storage.

ARGUMENTS:
    STUDY_DIR      Name of the study directory to thaw
    PROJECT_DIR    Name of the project directory to restore the study to

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
    thaw_study.sh study_mydata_20231120 myproject

EOF
}

# Get script dir
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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

me=$(whoami)
proj_fullpath="${PROJ_DIR}/${proj_name}"
fullpath="${PROJ_DIR}/${proj_name}/${study_dir}"

# Checks
## Check if dirs exist
if [[ ! -d "$proj_fullpath" ]]; then
    echo "Supplied project directory does not exist."
    exit 1
fi

## Check if study exists in freezer
if [[ -d "$fullpath" ]]; then
    echo "Study already thawed. Please verify name of the study."
    exit 1
fi

# Thaw study
echo "All checks passed, creating tarball and thawing..."
echo "Thawing tarball and transferring to Saga..."

## Get checksum before transfer
hash_pre=$(sha512sum "${FREEZE_DIR}/${study_dir}.tar.gz" | awk '{print $1}')

## Transfer file
rsync_err_file="$(mktemp)"

if rsync -avPW "${FREEZE_DIR}/${study_dir}.tar.gz" "$proj_fullpath" 2> "$rsync_err_file"; then
    rm -f "$rsync_err_file"
else
    status=$?
    echo "rsync failed with exit code $status" >&2
    echo "rsync error output:" >&2
    cat "$rsync_err_file" >&2
    rm -f "$rsync_err_file"
    exit "$status"
fi

## Verify checksum
echo "Verifying checksum after transfer..."
hash_post=$(sha512sum "${fullpath}.tar.gz" | awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    echo "Checksums are equal, transfer complete!"
else
    echo "Error: Checksums not equal. Please check files manually."
    rm -f "${fullpath:?}.tar.gz"
    exit 1
fi

## Unpack tarball
echo "Unpacking study..."
cd "$proj_fullpath"
tar -xzf "${study_dir}.tar.gz"
echo "Thawed by $me on $(date)" >> "${study_dir}/freeze_log.txt"
echo "$study_dir thawed by $me on $(date)" >> "${proj_fullpath}/freeze_log.txt"

## Cleanup
rm -f "${FREEZE_DIR:?}/${study_dir}.tar.gz"
rm -f "${study_dir:?}.tar.gz"
echo -e "$proj_name\t$study_dir\t$me\t$(date)" >> "${FREEZE_DIR}/thaw_log.txt"

# Reconstitute study data
echo "Reconstituting study data..."
(bash "${SCRIPT_DIR}/activate_data.sh" -c "${fullpath}/data.csv" -d "${study_dir##study_}")

echo "Comparing sha512sums..."
test=$( grep -Fxvf "${ACTIVE_DATA_DIR}/${study_dir##study_}/sha512sums.txt" "${fullpath}/sha512sums.txt" || true )

if [[ ! -z "${test}" ]]; then
    echo "sha512sums not equal, please check the following reads:"
    echo "$test"
    exit 1
else
    echo "sha512sum equal, thawing done!"
fi