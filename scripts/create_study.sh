#!/bin/bash

# Script used to generate study directories
# under a specific project directory, connected
# to the directory created with the activate script

# Checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No project directory name provided."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: No data directory provided."
    exit 1
fi

## Create dir variables
dest=/cluster/projects/nn9305k/projects/${1}
study_data=/cluster/shared/vetinst/active_data/${2}
study=${dest}/study_${2}
readme=/cluster/projects/nn9305k/development/adm/templates/study_readme.txt

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
mkdir $study
cp $readme ${study}/README.txt
cp ${study_data}/info.txt ${study}/data_info.txt
cp ${study_data}/reads.csv ${study}
cp ${study_data}/sha512sums.txt ${study}

echo "Creating symbolic links to read files..."
mkdir ${study}/data
ln -s ${study_data}/*fastq.gz ${study}/data

echo "Creating subdirectories..."
mkdir ${study}/sandbox
mkdir ${study}/results
mkdir ${study}/scripts

echo "Creation of study directory complete!"
echo "Make sure to fill out the README.txt file in the output directory."
