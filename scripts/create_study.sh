#!/bin/bash

# Script used to generate experiment directories
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
dest=/cluster/projects/nn9305k/development/projects/${1}
exp_data=/cluster/shared/vetinst/datasets/wgs/${2}
exp=${dest}/exp_${2}
readme=/cluster/projects/nn9305k/development/adm/templates/experiment_readme.txt

## Check if dirs exist
if ! test -d $dest; then
    echo "Supplied project directory does not exist."
    exit 1
fi

if ! test -d $exp_data; then
    echo "Supplied data directory does not exist."
    exit 1
fi

if test -d $exp; then
    echo "Output experiment directory already exists."
    exit 1
fi

# Create output dir and populate
echo "Creating output directory and populating files..."
mkdir $exp
cp $readme ${exp}/README.txt
cp ${exp_data}/info.txt ${exp}/data_info.txt
cp ${exp_data}/reads.csv ${exp}
cp ${exp_data}/sha512sums.txt ${exp}

echo "Creating symbolic links to read files..."
mkdir ${exp}/data
ln -s ${exp_data}/*fastq.gz ${exp}/data

echo "Creating subdirectories..."
mkdir ${exp}/sandbox
mkdir ${exp}/results
mkdir ${exp}/scripts

echo "Creation of experiment directory complete!"
echo "Make sure to fill out the README.txt file in the output directory."
