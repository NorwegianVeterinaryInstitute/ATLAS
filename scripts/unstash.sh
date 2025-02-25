#!/bin/bash

set -e

# Script for unstashing experiments
# Get input and set variables
exp_dir=$1
proj_dir=$2
me=$(whoami)
input=/nird/datalake/NS9305K/archive/experiment_stash
proj_loc=/cluster/projects/nn9305k/development/projects
proj_fullpath=${proj_loc}/${proj_dir}
fullpath=${proj_loc}/${proj_dir}/${exp_dir}
data_dir=/cluster/shared/vetinst/datasets/wgs

# Checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No experiment directory name provided."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: No project directory name provided."
    exit 1
fi

## Check if dirs exist
if ! test -d $proj_fullpath; then
    echo "Supplied project directory does not exist."
    exit 1
fi

## Check if experiment exists in stash
if [[ -d ${fullpath} ]]; then
    echo "Experiment already unstashed. Please verify name of the experiment."
    exit 1
fi

# Unstash experiment
echo "All checks passed, creating tarball and stashing..."
echo "Unstashing tarball and transferring to Saga..."

## Get checksum before transfer
hash_pre=$(sha512sum ${input}/${exp_dir}.tar.gz | awk '{print $1}')

## Transfer file
rsync -avPW ${input}/${exp_dir}.tar.gz $proj_fullpath

## Verify checksum
echo "Verifying checksum after transfer..."
hash_post=$(sha512sum ${fullpath}.tar.gz | awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    echo "Checksums are equal, transfer complete!"
else
    echo "Error: Checksums not equal. Please check files manually."
    rm -f ${fullpath}.tar.gz
    exit 1
fi

## Unpack tarball
echo "Unpacking experiment..."
cd $proj_fullpath
tar -xzf ${exp_dir}.tar.gz
echo "Unstashed by $me on $(date)" >> ${exp_dir}/stash_log.txt

## Cleanup
rm -f ${input}/${exp_dir}.tar.gz
rm -f ${exp_dir}.tar.gz
echo -e "$proj_dir\t$exp_dir\t$me\t$(date)" >> ${input}/unstash_log.txt

# Reconstitute experiment data
echo "Reconstituting experiment data..."
bash /cluster/projects/nn9305k/development/dev/saga_scripts/scripts/activate.sh ${fullpath}/reads.csv ${exp_dir##exp_}

echo "Comparing sha512sums..."
test=$(grep -Fxvf ${exp_dir##exp_}/sha512sums.txt ${fullpath}/sha512sums.txt)
if [ ! -z "${test}" ]; then
    echo "sha512sums not equal, please check the following reads:"
    echo $test
    exit 1
else
    echo "Unstashing done!"
fi


