#!/bin/bash

## Script used to transfer data from tarball location to ${ACTIVE_DATA_DIR}.

# Help function
show_help() {
    cat << EOF
Usage: activate_data.sh -c INPUT_CSV -d OUTPUT_DIR -a

Transfer data from tarball path to ${ACTIVE_DATA_DIR}.

ARGUMENTS:
    -c INPUT_CSV      Path to CSV file containing sample names and tarball paths
    -d OUTPUT_DIR     Output directory name in format: project_study_YYYYMMDD
    -a                Append mode (optional)
    -h                Show this help message

DESCRIPTION:
    This script performs the following operations:
    - Validates the CSV file and checks for tarball presence
    - Creates the output directory at ${ACTIVE_DATA_DIR}/OUTPUT_DIR
    - Extracts FASTQ files from tarballs specified in the CSV
    - Sets files to read-only (chmod 444)
    - Generates SHA512 checksums for all files
    - Creates metadata files (info.txt, reads.csv)

    The output directory name must follow the format: project_study_YYYYMMDD
    - No underscores allowed in project or study name parts
    - Date must be exactly 8 digits in YYYYMMDD format
    - Date must be a valid date

    CSV format: sample_name,/path/to/tarball.tar
    
    The CSV file can contain:
    - Quoted or unquoted fields: sample1,/path/to/tarball.tar OR "sample1","/path/to/tarball.tar"
    - Multiple tarballs per line: "sample1","/path/to/tarball1.tar,/path/to/tarball2.tar"
    - Empty lines: "",""

EXAMPLE:
    activate_data.sh -c samples.csv -d MyProj_Study1_20231120 -a

EOF
    exit 0
}

# Check flags
append=false
show_help=false

while getopts ":hac:d:" opt; do
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
            study_dir="$OPTARG"
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
if [[ -z "$csvfile" ]]; then
    echo "Error: Missing required argument -c (input CSV file)." >&2
    exit 1
fi

if [[ -z "$study_dir" ]]; then
    echo "Error: Missing required argument -d (output directory name)." >&2
    exit 1
fi

#Get input and set variables
## Get script dir
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    echo "Config not found: $CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"
source "$SCRIPT_DIR/lib.sh"

csv=$(realpath "$csvfile")
dest="${ACTIVE_DATA_DIR}/${study_dir}"

## Check for output directory name structure
### Check for project_study_date
regex='^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{8})$'

if [[ "$study_dir" =~ $regex ]]; then
    project="${BASH_REMATCH[1]}"
    study="${BASH_REMATCH[2]}"
    date_part="${BASH_REMATCH[3]}"

    # Validate the extracted date
    if ! date -d "${date_part}" +"%Y%m%d" &>/dev/null; then
        echo "Error: Invalid date. Please use a real date in YYYYMMDD format."
        exit 1
    fi
else
    # This runs only if the regex didn't match at all
    echo "Error: Input must follow the format project_study_date"
    echo "No underscores '_' allowed in project or study name"
    echo "Date has to be exactly 8 digits in the YYYYMMDD format"
    exit 1
fi

# Convert line endings to Unix format
dos2unix -q "$csv"

# Check tarball presence
if ! check_tarballs "$csv"; then
    exit 1
fi

echo "All tarballs found."
echo "Expected reads: $EXPECTED_READS"
loopcount=0

# Split at append flag
## Append mode
if $append; then
    echo "Append mode detected. This will append data to an existing study."
    read -p "Continue with appending data? (y/n): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        echo "Append cancelled."
        exit 1
    else
        if [[ -d "$dest" ]]; then
            echo "Directory detected. Files will be added to existing directory."
            cd "$dest" || exit
        else
            echo "Output directory does not exist, cannot append."
            exit 1
        fi
        echo "Detecting existing csv file..."
        if [[ -f "${dest}/data.csv" ]]; then
            echo "Existing csv file found. Checking for conflicts..."
            conflicts=$(find_append_conflicts "$csv" "${dest}/data.csv")
            status=$?

            if [[ $status -ne 0 ]]; then
                echo "Error: these sample/tarball combinations already exist:"
                printf '%s\n' "$conflicts"
                exit 1
            else
                echo "No conflicts found. Appending data..."
                # Run transfer
                transfer_files "$csv" "$append"
                # Log the transfer
                time=$(date)
                user=$(whoami)
                echo "Appended by" "$user" "on" "$time" >> append_log.txt
                echo "Project:" "$project" >> append_log.txt
                echo "Study: study_$2" >> append_log.txt
                tail -n +2 "$csv" >> "${dest}/data.csv"

                echo "Data appended successfully!"
            fi
        else
            echo "No existing csv file found. Cannot append data."
            exit 1
        fi
    fi
## Non-append mode
else
    # Directory check
    if [[ -d "$dest" ]]; then
        echo "Output directory already exists. Please choose a different name."
        exit 1
    else
        echo "Creating output directory"
        mkdir "$dest"
        cd "$dest" || exit
    fi
    # Transfer files
    transfer_files "$csv" "$append"
    
    # Create note file in subproject
    time=$(date)
    user=$(whoami)
    echo "Created by" "$user" "on" "$time" > info.txt
    echo "Project:" "$project" >> info.txt
    echo "Study: study_$2" >> info.txt
    cp "$csv" data.csv
    echo "Data activated!"
fi
    

