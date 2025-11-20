#!/bin/bash

set -e

# Script for thawing studies
# Get input and set variables
study_dir=$1
proj_dir=$2
me=$(whoami)
input=/nird/datapeak/NS9305K/study_freezer
proj_loc=/cluster/projects/nn9305k/projects
proj_fullpath=${proj_loc}/${proj_dir}
fullpath=${proj_loc}/${proj_dir}/${study_dir}
data_dir=/cluster/shared/vetinst/active_data

# Checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No study directory name provided."
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

## Check if study exists in freezer
if [[ -d ${fullpath} ]]; then
    echo "Study already thawed. Please verify name of the study."
    exit 1
fi

# Thaw study
echo "All checks passed, creating tarball and thawing..."
echo "Unthawing tarball and transferring to Saga..."

## Get checksum before transfer
hash_pre=$(sha512sum ${input}/${study_dir}.tar.gz | awk '{print $1}')

## Transfer file
rsync -avPW ${input}/${study_dir}.tar.gz $proj_fullpath

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
echo "Unpacking study..."
cd $proj_fullpath
tar -xzf ${study_dir}.tar.gz
echo "Thawed by $me on $(date)" >> ${study_dir}/freeze_log.txt
echo $study_dir "thawed by" $me "on $(date)" >> ${proj_fullpath}/freeze_log.txt

## Cleanup
rm -f ${input}/${study_dir}.tar.gz
rm -f ${study_dir}.tar.gz
echo -e "$proj_dir\t$study_dir\t$me\t$(date)" >> ${input}/freeze_log.txt

# Reconstitute study data
echo "Reconstituting study data..."
(bash /cluster/projects/nn9305k/development/dev/saga_scripts/scripts/activate_data.sh "${fullpath}/reads.csv" "${study_dir##study_}")

echo "Comparing sha512sums..."
test=$( grep -Fxvf ${data_dir}/${study_dir##study_}/sha512sums.txt ${fullpath}/sha512sums.txt || true )

if [ ! -z "${test}" ]; then
    echo "sha512sums not equal, please check the following reads:"
    echo $test
    exit 1
else
    echo "sha512sum equal, thawing done!"
fi