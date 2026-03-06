#!/bin/bash

# Script used to generate study directories
# under a specific project directory, connected
# to the directory created with the activate script

# Help function
show_help() {
    cat << EOF
Usage: create_study.sh -p PROJECT_DIR -d DATA_DIR

Generate study directories under a specific project directory, connected
to the directory created with the activate script.

ARGUMENTS:
    -p PROJECT_DIR    Name of the project directory
    -d DATA_DIR       Name of the data directory
    -h                Show this help message

DESCRIPTION:
    This script creates a study directory structure with the following:
    - Study directory at ${PROJECT_DIR}/study_DATA_DIR
    - README.txt file
    - data_info.txt (copied from active_data)
    - data.csv (copied from active_data)
    - sha512sums.txt (copied from active_data)
    - Symbolic links to FASTQ files in data/ subdirectory
    - Subdirectories: sandbox, results, scripts

EXAMPLE:
    create_study.sh -p myproject -d mydata_study_20231120

EOF
}

# Checks
## Check for help flag
while getopts ":hp:d:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        p)
            proj_name="$OPTARG"
            ;;
        d)
            study_data="$OPTARG"
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
if [[ -z "$study_data" ]]; then
    echo "Error: Missing required argument -d (data directory name)." >&2
    exit 1
fi

if [[ -z "$proj_name" ]]; then
    echo "Error: Missing required argument -p (project directory name)." >&2
    exit 1
fi

## Create dir variables
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    echo "Config not found: $CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"

dest="${PROJ_DIR}/${proj_name}"
study_data="${ACTIVE_DATA_DIR}/${study_data}"
study="${dest}/study_$(basename "$study_data")"
readme="${TEMPLATE_DIR}/study_readme.txt"

## Check if dirs exist
if [[ ! -d "$dest" ]]; then
    echo "Supplied project directory does not exist."
    exit 1
fi

if [[ ! -d "$study_data" ]]; then
    echo "Supplied data directory does not exist."
    exit 1
fi

if [[ -d "$study" ]]; then
    echo "Output study directory already exists."
    exit 1
fi

# Create output dir and populate
echo "Creating output directory and populating files..."
mkdir "$study"
cp "$readme" "${study}/README.txt"
cp "${study_data}/info.txt" "${study}/data_info.txt"
cp "${study_data}/data.csv" "${study}"
cp "${study_data}/sha512sums.txt" "${study}"
cp "${study_data}/transferred_reads.txt" "${study}" 

echo "Creating symbolic links to read files..."
mkdir "${study}/data"
ln -s "${study_data}"/*fastq.gz "${study}/data"

echo "Creating subdirectories..."
mkdir "${study}/sandbox"
mkdir "${study}/results"
mkdir "${study}/scripts"

echo "Creation of study directory complete!"
echo "Make sure to fill out the README.txt file in the output directory."
