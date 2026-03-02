#!/bin/bash

# Script used to generate study directories
# under a specific project directory, connected
# to the directory created with the activate script

# Help function
show_help() {
    cat << EOF
Usage: create_study.sh PROJECT_DIR DATA_DIR

Generate study directories under a specific project directory, connected
to the directory created with the activate script.

ARGUMENTS:
    PROJECT_DIR    Name of the project directory
    DATA_DIR       Name of the data directory

DESCRIPTION:
    This script creates a study directory structure with the following:
    - Study directory at ${PROJECT_DIR}/study_DATA_DIR
    - README.txt file
    - data_info.txt (copied from active_data)
    - reads.csv (copied from active_data)
    - sha512sums.txt (copied from active_data)
    - Symbolic links to FASTQ files in data/ subdirectory
    - Subdirectories: sandbox, results, scripts

EXAMPLE:
    create_study.sh myproject mydata_study_20231120

EOF
    exit 0
}

# Checks
## Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No project directory name provided."
    echo "Use -h or --help for usage information."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: No data directory provided."
    echo "Use -h or --help for usage information."
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

dest="${PROJ_DIR}/${1}"
study_data="${ACTIVE_DATA_DIR}/${2}"
study="${dest}/study_${2}"
readme="${TEMPLATE_DIR}/study_readme.txt"

## Check if dirs exist
if ! test -d $dest; then
    echo "Supplied project directory does not exist."
    exit 1
fi

if ! test -d $study_data; then
    echo "Supplied data directory does not exist."
    exit 1
fi

if test -d $study; then
    echo "Output study directory already exists."
    exit 1
fi

# Create output dir and populate
echo "Creating output directory and populating files..."
mkdir "$study"
cp "$readme" "${study}/README.txt"
cp "${study_data}/info.txt" "${study}/data_info.txt"
cp "${study_data}/reads.csv" "${study}"
cp "${study_data}/sha512sums.txt" "${study}"

echo "Creating symbolic links to read files..."
mkdir "${study}/data"
ln -s "${study_data}"/*fastq.gz "${study}/data"

echo "Creating subdirectories..."
mkdir "${study}/sandbox"
mkdir "${study}/results"
mkdir "${study}/scripts"

echo "Creation of study directory complete!"
echo "Make sure to fill out the README.txt file in the output directory."
