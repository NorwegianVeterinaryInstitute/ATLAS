#!/bin/bash

# Script used to create a project directory in the
# nn9305k/projects directory

# Help function
show_help() {
    cat << EOF
Usage: create_project.sh -p PROJECT_NAME

Create a project directory in the ${PROJ_DIR} directory.

ARGUMENTS:
    -p PROJECT_NAME   Name of the project in format: projectNumber_projectName
    -h                Show this help message

DESCRIPTION:
    This script creates a new project directory with the following:
    - Project directory at ${PROJ_DIR}/PROJECT_NAME
    - creation.txt file with timestamp and creator information
    - README.txt template file

    The project name must follow the format: projectNumber_projectName
    - No underscores allowed in the project number or project name parts
    - If no project number is available, use other informative info instead

EXAMPLE:
    create_project.sh 12345_MyProject
    create_project.sh VetInst_BacterialGenomics

EOF
    exit 0
}

# Checks
## Check for help flag
show_help=false

while getopts ":hp:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
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
if [[ -z "$proj_name" ]]; then
    echo "Error: Missing required argument -p (project directory name)." >&2
    exit 1
fi

# Fetch variables
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    echo "Config not found: $CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"

dest="${PROJ_DIR}/${proj_name}"
readme="${TEMPLATE_DIR}/project_readme.txt"

# Checks
## Check for user-supplied parameters
if [[ -z "$1" ]]; then
    echo "Error: No project name supplied."
    echo "Use -h or --help for usage information."
    exit 1
fi

## Check for input project name structure
regex='^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)$'

if [[ "$proj_name" =~ $regex ]]; then
    proj_num="${BASH_REMATCH[1]}"
    proj_name="${BASH_REMATCH[2]}"
else
    echo "Error: Input must follow the format projectNumber_projectName"
    echo "No underscores '_' allowed in project number or project name"
    echo "If no project number is available, use other informative info instead."
    exit 1
fi

## Check if destination dir exists
if [[ -d "$dest" ]]; then
    echo "Output directory already exists. Please choose a different name."
    exit 1
fi

# Create project directory and subfiles
echo "Creating project directory and populating files..."
mkdir "$dest"
user=$(whoami)
echo "Created by $user on $(date)" > "${dest}/creation.txt"
cp "$readme" "${dest}/README.txt"
echo "Project $proj_name created in $dest."
echo "Please fill out the README.txt file in the project directory."
