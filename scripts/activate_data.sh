#!/bin/bash

## Script used to transfer data from tarball location to ${ACTIVE_DATA_DIR}.

# Help function
show_help() {
    cat << EOF
Usage: activate_data.sh -c INPUT_CSV -d OUTPUT_DIR [-a -p PROJECT_NAME]

Transfer data from tarball path to ACTIVE_DATA_DIR.

ARGUMENTS:
    -c INPUT_CSV      Path to CSV file containing sample names and tarball paths
    -d OUTPUT_DIR     Output directory name in format: project_study_YYYYMMDD
    -p PROJECT_NAME   Name of the project directory (optional, to be used with append mode)
    -a                Append mode (optional)
    -h                Show this help message

DESCRIPTION:
    This script performs the following operations:
    - Validates the CSV file and checks for tarball presence
    - Stops if two reads, or a read and an existing file, share a file name
    - Creates the output directory at ACTIVE_DATA_DIR/OUTPUT_DIR
    - Extracts FASTQ files from tarballs specified in the CSV
    - Sets files to read-only (chmod 444)
    - Generates SHA512 checksums for all files
    - Creates metadata files (info.txt, data.csv)

    The output directory name must follow the format: project_study_YYYYMMDD
    - No underscores allowed in project or study name parts
    - Date must be exactly 8 digits in YYYYMMDD format
    - Date must be a valid date

    CSV format: sample_name,/path/to/tarball.tar

    Tarballs must be uncompressed and named *.tar.

    A header line is optional and its column names are free. The first line is
    treated as a header when its second field does not end in .tar.

    The CSV file can contain:
    - Quoted or unquoted fields: sample1,/path/to/tarball.tar OR "sample1","/path/to/tarball.tar"
    - Multiple tarballs per line: "sample1","/path/to/tarball1.tar,/path/to/tarball2.tar"
    - Empty lines: "",""

    Append mode (-a) allows adding new samples to an existing study directory. Supplying the 
    project directory name associated with the existing study is required in append mode (-p). 
    In append mode, the script will check for conflicts with existing sample/tarball 
    combinations and will not proceed if conflicts are found. The script will then append new 
    data to the existing directory and update the data.csv file.

EXAMPLE:
    activate_data.sh -c samples.csv -d MyProj_Study1_20231120 -p 12345_MyProj -a

EOF
}

# Check flags
append=false

while getopts ":hac:d:p:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        a)
            append=true
            ;;
        c)
            csvfile="$OPTARG"
            ;;
        d)
            data_dir="$OPTARG"
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
if [[ -z "$csvfile" ]]; then
    printf "Error: Missing required argument -c (input CSV file).\n" >&2
    exit 1
fi

if [[ -z "$data_dir" ]]; then
    printf "Error: Missing required argument -d (output directory name).\n" >&2
    exit 1
fi

if [[ "$append" = true && -z "$proj_name" ]]; then
    printf "Error: Append mode requires -p (project directory name).\n" >&2
    exit 1
fi


#Get input and set variables
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

if [[ ! -f "$csvfile" ]]; then
    printf "Error: CSV file not found: %s\n" "$csvfile" >&2
    exit 1
fi
dest="${ACTIVE_DATA_DIR}/${data_dir}"

## Check for output directory name structure
### Check for project_study_date
regex='^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{8})$'

if [[ "$data_dir" =~ $regex ]]; then
    project="${BASH_REMATCH[1]}"
    date_part="${BASH_REMATCH[3]}"

    # Validate the extracted date
    if ! /usr/bin/date -d "${date_part}" +"%Y%m%d" &>/dev/null; then
        printf "Error: Invalid date. Please use a real date in YYYYMMDD format.\n"
        exit 1
    fi
else
    # This runs only if the regex didn't match at all
    printf "Error: Input must follow the format project_study_date\n"
    printf "No underscores '_' allowed in project or study name\n"
    printf "Date has to be exactly 8 digits in the YYYYMMDD format\n"
    exit 1
fi

# Read the CSV into memory with Unix line endings, leaving the user's file
# untouched. $(...) drops trailing newlines; csv_rows adds exactly one back,
# so every copy ends with a newline even if the file did not.
csv_data=$(/usr/bin/dos2unix < "$csvfile")

# The header is optional. Line 1 is a data row if its tarball field ends in
# .tar, otherwise it is a header and dropped. csv_rows always puts a fixed
# header first, so the readers in lib.sh can keep skipping line 1.
IFS="," read -r _ first_tarball <<< "$csv_data"
first_tarball=$(strip_quotes "$first_tarball" | /usr/bin/xargs)
if [[ -n "$csv_data" && "$first_tarball" != *.tar ]]; then
    printf "Header detected, skipping: %s\n" "${csv_data%%$'\n'*}"
    csv_data=$(printf "%s\n" "$csv_data" | /usr/bin/tail -n +2)
fi

# Rows like "","" are skipped by the readers, so they do not count
if ! printf "%s\n" "$csv_data" | /usr/bin/grep -q '[^,"[:space:]]'; then
    printf "Error: No samples found in CSV file: %s\n" "$csvfile" >&2
    exit 1
fi

csv_rows() {
    printf "sample,tarball\n"
    [[ -n "$csv_data" ]] && printf "%s\n" "$csv_data"
}

# Check tarball presence
if ! check_tarballs <(csv_rows); then
    exit 1
fi

printf "All tarballs found.\n"
printf "Expected reads: %s\n" "$EXPECTED_READS"

# Check the output directories, before asking or changing anything
if $append; then
    study_dir="${PROJ_DIR}/${proj_name}/study_${data_dir}"
    if [[ ! -d "$dest" || ! -d "$study_dir" ]]; then
        printf "Output directories do not exist, cannot append.\n"
        exit 1
    fi
    if [[ ! -f "${dest}/data.csv" ]]; then
        printf "No existing csv file found. Cannot append data.\n"
        exit 1
    fi
    if ! conflicts=$(find_append_conflicts <(csv_rows) "${dest}/data.csv"); then
        printf "Error: these sample/tarball combinations already exist in the study:\n"
        printf '%s\n' "$conflicts"
        exit 1
    fi
    clash_dir="$dest"
else
    if [[ -d "$dest" ]]; then
        printf "Output directory already exists. Please choose a different name.\n"
        exit 1
    fi
    clash_dir=""
fi

# Reads are moved into one directory by file name, so two with the same name
# would overwrite each other. In append mode, dest already holds reads.
if ! clashes=$(find_read_clashes <(csv_rows) "$clash_dir"); then
    printf "Error: these read files would overwrite each other or existing reads:\n" >&2
    printf "%s\n" "$clashes" >&2
    printf "Make the sample names unambiguous or split the input. Nothing was changed.\n" >&2
    exit 1
fi

# Split at append flag
## Append mode
if $append; then
    printf "Append mode detected. This will append data to an existing study.\n"
    read -r -p "Continue with appending data? (y/n): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        printf "Append cancelled.\n"
        exit 1
    fi

    printf "No conflicts found. Files will be added to the existing directory.\n"
    # Extract into a staging directory and move the reads into place only
    # when all of them are there, so a failed append leaves dest unchanged
    staging="${dest}/.append_in_progress"
    if ! /usr/bin/mkdir "$staging"; then
        if [[ -e "$staging" ]]; then
            printf "Error: %s already exists. An earlier append was interrupted; remove it and rerun.\n" "$staging" >&2
        else
            printf "Error: Could not create %s. Check that you can write to %s.\n" "$staging" "$dest" >&2
        fi
        exit 1
    fi
    trap '/usr/bin/rm -rf "${staging:?}"' EXIT
    cd "$staging" || exit
    # Run transfer
    if ! transfer_files <(csv_rows) "$append"; then
        printf "Error: Append failed. Nothing was changed in %s or the study.\n" "$dest" >&2
        exit 1
    fi
    # Move the reads into dest and append the new data.csv rows, checksums
    # and read lists to the files there. Appending in place needs only write
    # access to the files; replacing them can fail in a shared directory.
    # Record the list sizes first, so a failure can undo the appends, and
    # remove the moved reads, which were checked not to exist in dest.
    if ! csv_rows | /usr/bin/tail -n +2 > data.csv; then
        printf "Error: Could not write the new data.csv rows. Nothing was changed in %s or the study.\n" "$dest" >&2
        exit 1
    fi
    lists=()
    declare -A list_size=()
    for list in data.csv sha512sums.txt appended_reads.txt missing_in_some_tarballs.csv; do
        [[ -f "$list" ]] || continue
        lists+=("$list")
        [[ -f "${dest}/${list}" ]] || continue
        if ! list_size[$list]=$(/usr/bin/stat -c %s "${dest}/${list}"); then
            printf "Error: Could not read %s. Nothing was changed in %s or the study.\n" "${dest}/${list}" "$dest" >&2
            exit 1
        fi
    done
    moved=()
    touched=()
    # Undo the moves and the appends tried so far. A list is only cut back
    # if its size changed (a failed append may have written part of it).
    undo_append() {
        local f size
        local -a not_undone=()
        for f in "${moved[@]}"; do
            /usr/bin/rm -f "${dest:?}/${f}" || not_undone+=("$f")
        done
        for f in "${touched[@]}"; do
            if [[ -n "${list_size[$f]:-}" ]]; then
                size=$(/usr/bin/stat -c %s "${dest}/${f}") || size=""
                if [[ "$size" != "${list_size[$f]}" ]] &&
                    ! /usr/bin/truncate -s "${list_size[$f]}" "${dest}/${f}"; then
                    not_undone+=("$f")
                fi
            else
                /usr/bin/rm -f "${dest:?}/${f}" || not_undone+=("$f")
            fi
        done
        if [[ ${#not_undone[@]} -gt 0 ]]; then
            printf "Error: Could not undo the append. Check these files in %s:\n" "$dest" >&2
            printf "  %s\n" "${not_undone[@]}" >&2
        else
            printf "Nothing was changed in %s or the study.\n" "$dest" >&2
        fi
    }
    # From here on any exit, a signal included, undoes what was done
    trap 'undo_append; /usr/bin/rm -rf "${staging:?}"' EXIT
    while IFS= read -r read_file; do
        # The clash check ran before the extraction; make sure nothing with
        # this name appeared in dest since, as mv would overwrite it and the
        # undo would then delete it
        if [[ -e "${dest}/${read_file}" || -L "${dest}/${read_file}" ]]; then
            printf "Error: %s appeared in %s during the append\n" "$read_file" "$dest" >&2
            exit 1
        fi
        # Recorded before the move, so a signal right after it is undone too
        moved+=("$read_file")
        if ! /usr/bin/mv "$read_file" "${dest}/"; then
            printf "Error: Could not move %s into %s\n" "$read_file" "$dest" >&2
            exit 1
        fi
    done < appended_reads.txt
    for list in "${lists[@]}"; do
        touched+=("$list")
        if ! /usr/bin/cat "$list" >> "${dest}/${list}"; then
            printf "Error: Could not update %s\n" "${dest}/${list}" >&2
            exit 1
        fi
    done
    trap - EXIT
    cd "$dest" || exit
    /usr/bin/rm -rf "${staging:?}"
    # Log the transfer
    time=$(/usr/bin/date)
    user=$(/usr/bin/whoami)

    {
        printf "Appended by %s on %s\n" "$user" "$time";
        printf "Project: %s\n" "$project";
        printf "Study: study_%s\n" "$data_dir";
    } >> append_log.txt

    printf "Copying information to study directory...\n"
    /usr/bin/cp "${dest}/data.csv" "${study_dir}/data.csv"
    /usr/bin/cp "${dest}/append_log.txt" "${study_dir}/append_log.txt"
    /usr/bin/cp "${dest}/appended_reads.txt" "${study_dir}/appended_reads.txt"
    /usr/bin/cp sha512sums.txt "${study_dir}/sha512sums.txt"

    printf "Adding symlinks...\n"
    if ! link_reads "${ACTIVE_DATA_DIR}/${data_dir}" "${study_dir}/data"; then
        printf "Error: Could not link all read files into %s\n" "${study_dir}/data" >&2
        exit 1
    fi

    printf "Data appended successfully!\n"
## Non-append mode
else
    printf "Creating output directory.\n"
    if ! /usr/bin/mkdir "$dest"; then
        exit 1
    fi
    # dest was checked not to exist, so a failure removes only what this
    # run created
    trap '/usr/bin/rm -rf "${dest:?}"' EXIT
    cd "$dest" || exit
    # Transfer files
    if ! transfer_files <(csv_rows) "$append"; then
        printf "Error: Activation failed; removed %s. Fix the problem and rerun.\n" "$dest" >&2
        exit 1
    fi

    # Create note file in subproject
    time=$(/usr/bin/date)
    user=$(/usr/bin/whoami)

    {
        printf "Created by %s on %s\n" "$user" "$time";
        printf "Project: %s\n" "$project";
        printf "Study: study_%s\n" "$data_dir";
    } >> info.txt

    csv_rows > data.csv
    trap - EXIT
    printf "Data activated!\n"
fi
    

