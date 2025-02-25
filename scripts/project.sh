#!/bin/bash

# Script used to create a project directory in the
# nn9305k/projects directory

# Fetch variables
proj_name=$1
dest=/cluster/projects/nn9305k/development/projects/${proj_name}
readme=/cluster/projects/nn9305k/development/adm/templates/project_readme.txt

# Checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No project name supplied."
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
echo "Created by $user on $time" > ${dest}/creation.txt
cp $readme $dest/README.txt
echo "Done! Project" $proj_name "created in" $dest "."
echo "Please fill out the README.txt file in the project directory."
