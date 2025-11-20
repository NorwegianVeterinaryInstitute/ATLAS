#!/bin/bash

# Script used to create a project directory in the
# nn9305k/projects directory

# Help function
show_help() {
    cat << EOF
Usage: create_project.sh PROJECT_NAME

Create a project directory in the nn9305k/projects directory.

ARGUMENTS:
    PROJECT_NAME   Name of the project in format: projectNumber_projectName

DESCRIPTION:
    This script creates a new project directory with the following:
    - Project directory at /cluster/projects/nn9305k/projects/PROJECT_NAME
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
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Fetch variables
proj_name=$1
dest=/cluster/projects/nn9305k/projects/${proj_name}
readme=/cluster/projects/nn9305k/development/adm/templates/project_readme.txt

# Checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
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
if test -d $dest; then
    echo "Output directory already exists. Please choose a different name."
    exit 1
fi

# Create project directory and subfiles
echo "Creating project directory and populating files..."
mkdir $dest
user=$(whoami)
echo "Created by" $user "on $(date)" > ${dest}/creation.txt
cp $readme $dest/README.txt
echo "Project" $proj_name "created in" $dest"."
echo "Please fill out the README.txt file in the project directory."
