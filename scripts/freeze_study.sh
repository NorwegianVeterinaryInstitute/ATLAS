#!/bin/bash

set -e

# Script for freezing studies
# Get input and set variables
study_dir=$1
proj_dir=$2
me=$(whoami)
output=/nird/datalake/NS9305K/archive/study_stash
proj_loc=/cluster/projects/nn9305k/development/projects
proj_fullpath=${proj_loc}/${proj_dir}
fullpath=${proj_loc}/${proj_dir}/${study_dir}
data_dir=/cluster/shared/vetinst/datasets/wgs

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

if ! test -d $fullpath; then
    echo "Supplied study directory does not exist."
    exit 1
fi

## Check if study exists in freezer
if [[ -d ${output}/${study_dir}.tar.gz ]]; then
    echo "Study already frozen. Please verify name of the study."
    exit 1
fi

# Create study tarball
echo "All checks passed, creating tarball and freezing..."
echo "Frozen by $me on $(date)" >> ${fullpath}/stash_log.txt

cd $proj_fullpath
tar -czf ${study_dir}.tar.gz $study_dir

# Verify tarball archive
echo "Verifying archive..."
if tar -tzf ${study_dir}.tar.gz > /dev/null; then
    echo "Archive verification successful!"
else
    echo "Error: Archive verification failed. Deleting corrupt archive."
    rm -f ${study_dir}.tar.gz
    exit 1
fi

# Get checksum of archive
echo "Creating checksum of archive..."
hash_pre=$(sha512sum ${study_dir}.tar.gz | awk '{print $1}')

# Transfer tarball to storage
echo "Moving archive to NIRD..."
rsync -avPW ${study_dir}.tar.gz $output

# Check tarball checksum after transfer
echo "Verifying checksum after transfer..."
hash_post=$(sha512sum ${output}/${study_dir}.tar.gz | awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    echo "Checksums are equal!"
else
    echo "Error: Checksums not equal. Please check files manually."
    rm -f ${output}/${study_dir}.tar.gz
    exit 1
fi

# Log the freezing and cleanup
echo "Logging the freezing and cleaning up files..."
echo $study_dir "frozen by" $me "on $(date)" >> ${proj_fullpath}/freeze_log.txt
echo -e "$proj_dir\t$study_dir\t$me\t$(date)" >> ${output}/freeze_log.txt
rm -rf ${fullpath}
rm -f ${fullpath}.tar.gz
rm -rf ${data_dir}/${study_dir##study_}

echo "Freezing complete!"
