#!/bin/bash

set -eo pipefail

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
    - Checks that the source tarballs in the frozen study's data.csv exist
    - Retrieves a frozen study from the freeze directory (FREEZE_DIR)
    - Verifies checksums before and after transfer
    - Unpacks the tarball to restore the study directory
    - Reconstitutes the study data using activate_data.sh
    - Verifies sha512sums of the restored data
    - Removes the tarball from freezer after successful restoration
    - Logs the thawing operation

    This script is used to restore studies that were previously frozen
    using the freeze_study.sh script. The reads are extracted again from
    the source tarballs listed in the study's data.csv.

    If thawing fails, the tarball stays in the freezer and the study and
    active data directories created by the run are removed. Fix the
    problem and rerun.

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
if [[ -z "$study_dir" ]]; then
    printf "Error: Missing required argument -s (study directory name).\n" >&2
    exit 1
fi

if [[ -z "$proj_name" ]]; then
    printf "Error: Missing required argument -p (project directory name).\n" >&2
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
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

me=$(/usr/bin/whoami)
proj_fullpath="${PROJ_DIR}/${proj_name}"
fullpath="${PROJ_DIR}/${proj_name}/${study_dir}"
frozen="${FREEZE_DIR}/${study_dir}.tar.gz"
active_dir="${ACTIVE_DATA_DIR}/${study_dir##study_}"

# Checks
## Check if dirs exist
if [[ ! -d "$proj_fullpath" ]]; then
    printf "Supplied project directory does not exist.\n" >&2
    exit 1
fi

## Check if study already exists in project directory. Thaw removes the
## study and active data directories when it fails, so neither may exist
## beforehand.
if [[ -e "$fullpath" ]]; then
    printf "Study already thawed. Please verify name of the study.\n" >&2
    exit 1
fi

if [[ -e "$active_dir" ]]; then
    printf "Active data directory already exists: %s\n" "$active_dir" >&2
    exit 1
fi

if [[ ! -f "$frozen" ]]; then
    printf "Frozen study not found: %s\n" "$frozen" >&2
    exit 1
fi

## Thawing extracts the reads again from the source tarballs: check them
## before writing anything, using the data.csv inside the frozen study
if ! frozen_csv=$(/usr/bin/tar -xzOf "$frozen" "${study_dir}/data.csv" | /usr/bin/dos2unix); then
    printf "Error: Could not read %s from %s\n" "${study_dir}/data.csv" "$frozen" >&2
    exit 1
fi

if ! check_tarballs <(printf "%s\n" "$frozen_csv") false; then
    printf "Thawing needs the source tarballs. Nothing was changed.\n" >&2
    exit 1
fi

# Thaw study
printf "All checks passed, transferring to project directory and thawing...\n"

## From here on, a failure removes everything this run created. The frozen
## copy is the source of truth and stays until the thaw is verified.
cleanup_failed_thaw() {
    /usr/bin/rm -f "${fullpath:?}.tar.gz"
    /usr/bin/rm -rf "${fullpath:?}" "${active_dir:?}"
    printf "Thaw failed. Removed %s and %s; the frozen study is kept at %s.\n" "$fullpath" "$active_dir" "$frozen" >&2
    printf "Fix the problem and rerun.\n" >&2
}
trap cleanup_failed_thaw EXIT

## Get checksum before transfer
hash_pre=$(/usr/bin/sha512sum "$frozen" | /usr/bin/awk '{print $1}')

## Transfer file
rsync_err_file="$("/usr/bin/mktemp")"

if /usr/bin/rsync -avPW "$frozen" "${proj_fullpath}/" 2> "$rsync_err_file"; then
    /usr/bin/rm -f "${rsync_err_file:?}"
else
    status=$?
    printf "rsync failed with exit code %d\n" "$status" >&2
    printf "rsync error output:\n" >&2
    /usr/bin/cat "$rsync_err_file" >&2
    /usr/bin/rm -f "${rsync_err_file:?}"
    exit "$status"
fi

## Verify checksum
printf "Verifying checksum after transfer...\n"
hash_post=$(/usr/bin/sha512sum "${fullpath}.tar.gz" | /usr/bin/awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    printf "Checksums are equal, transfer complete!\n"
else
    printf "Error: Checksums not equal after transfer.\n" >&2
    exit 1
fi

## Unpack tarball
cd "$proj_fullpath"

/usr/bin/tar -xzf "${study_dir}.tar.gz"
## The copy in the freezer stays until the data is verified
/usr/bin/rm -f "${study_dir:?}.tar.gz"

# Reconstitute study data
printf "Reconstituting study data...\n"
if ! /usr/bin/bash "${SCRIPT_DIR}/activate_data.sh" -c "${fullpath}/data.csv" -d "${study_dir##study_}"; then
    printf "Error: Could not restore the study data.\n" >&2
    exit 1
fi

printf "Comparing sha512sums...\n"
test=$( /usr/bin/grep -Fxvf "${active_dir}/sha512sums.txt" "${fullpath}/sha512sums.txt" || true )

if [[ -n "${test}" ]]; then
    printf "sha512sums not equal, please check the following reads:\n" >&2
    printf "%s\n" "$test" >&2
    exit 1
fi

## Thaw verified: keep what was restored even if logging fails
trap - EXIT

## Log and cleanup
printf "Thawed by %s on %s\n" "$me" "$(/usr/bin/date)" >> "${fullpath}/freeze_log.txt"
printf "%s thawed by %s on %s\n" "$study_dir" "$me" "$(/usr/bin/date)" >> "${proj_fullpath}/freeze_log.txt"
printf "%s\t%s\t%s\t%s\n" "$proj_name" "$study_dir" "$me" "$(/usr/bin/date)" >> "${FREEZE_DIR}/thaw_log.txt"
/usr/bin/rm -f "${frozen:?}"

printf "sha512sum equal, thawing done!\n"