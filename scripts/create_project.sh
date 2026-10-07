#!/bin/bash

# Script used to create a project directory in the
# nn9305k/projects directory

# Help function
show_help() {
    cat << 'EOF'
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
    create_project.sh -p 12345_MyProject
    create_project.sh -p VetInst_BacterialGenomics

EOF
}

# Checks
## Check for help flag
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

# Fetch variables
## Get config variables
CONFIG_FILE="${ATLAS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh}"

[[ -f "$CONFIG_FILE" ]] || {
    printf "Config not found: %s\n" "$CONFIG_FILE" >&2
    exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"

dest="${PROJ_DIR}/${proj_name}"
readme="${TEMPLATE_DIR}/project_readme.txt"

# Checks
## Check if project readme exists
if [[ ! -f "$readme" ]]; then
    printf "Error: Project README template not found at %s\n" "$readme" >&2
    exit 1
fi

## Check for input project name structure
regex='^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)$'

if [[ "$proj_name" =~ $regex ]]; then
    proj_name="${BASH_REMATCH[2]}"
else
    printf "Error: Input must follow the format projectNumber_projectName\n" >&2
    printf "No underscores '_' allowed in project number or project name\n" >&2
    printf "If no project number is available, use other informative info instead.\n" >&2
    exit 1
fi

## Check if destination dir exists
if [[ -d "$dest" ]]; then
    printf "Output directory already exists. Please choose a different name.\n" >&2
    exit 1
fi

# Create project directory and subfiles
printf "Creating project directory and populating files...\n"
/usr/bin/mkdir "$dest"
user=$(/usr/bin/whoami)
printf "Created by %s on %s\n" "$user" "$(/usr/bin/date)" > "${dest}/creation.txt"
/usr/bin/cp "$readme" "${dest}/README.txt"
printf "Project %s created in %s.\n" "$proj_name" "$dest"
printf "Please fill out the README.txt file in the project directory.\n"
