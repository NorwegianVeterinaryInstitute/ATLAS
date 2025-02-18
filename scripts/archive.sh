#!/bin/bash

set -e

# Script for archiving experiments.
# The script will create a tarball of the
# experiment directory, and transfer the
# tarball to the correct location on NIRD.

# --------------------------------------------------
# Get input and set variables
exp_dir=$1
proj_dir=$2
proj_loc=/cluster/projects/nn9305k/development/projects
proj_fullpath=${proj_loc}/${proj_dir}
fullpath=${proj_loc}/${proj_dir}/${exp_dir}
output=/nird/datalake/NS9305K/archive/experiment_archive

# --------------------------------------------------
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

if ! test -d $fullpath; then
    echo "Supplied experiment directory does not exist."
    exit 1
fi

## Check directory size
size_kb=$(du -s "$fullpath" | awk '{print $1}')
size_mb=$((size_kb / 1024))
size_gb=$((size_mb / 1024))

threshold=250

if (( size_gb > threshold )); then
    echo "Warning: Experiment directory '$exp_dir' is very large (~${size_gb}GB)."
    echo "Please consider removing additional redundant or intermediary files."
    read -p "Continue archiving anyway? (y/n): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        echo "Archiving cancelled."
        exit 1
    fi
fi

## Check if sandbox archive is removed
if [[ -d "$fullpath/sandbox" ]]; then
    echo "The sandbox directory is still present in the experiment."
    echo "Please delete it before archiving."
    exit 1
fi

## Check if experiment exists in the archive
if [[ -d ${output}/${exp_dir}.tar.gz ]]; then
    echo "Experiment already archived. Please verify name of the experiment."
    exit 1
fi

# --------------------------------------------------
# Create experiment tarball
echo "All checks passed, creating tarball..."
tar -czf ${fullpath}.tar.gz $fullpath

# Verify tarball archive
echo "Verifying archive..."
if tar -tzf ${fullpath}.tar.gz > /dev/null; then
    echo "Archive verification successful!"
else
    echo "Error: Archive verification failed. Deleting corrupt archive."
    rm -f ${fullpath}.tar.gz
    exit 1
fi

# --------------------------------------------------
# Get checksum of archive
echo "Creating checksum of archive..."
hash_pre=$(sha512sum ${fullpath}.tar.gz | awk '{print $1}')

# --------------------------------------------------
# Transfer tarball to storage
echo "Moving archive to NIRD..."
rsync -avPW ${fullpath}.tar.gz $output

# --------------------------------------------------
# Check tarball checksum after transfer
echo "Verifying checksum after transfer..."
hash_post=$(sha512sum ${output}/${exp_dir}.tar.gz | awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    echo "Checksums are equal, transfer complete!"
else
    echo "Error: Checksums not equal. Please check files manually."
    exit 1
fi

# --------------------------------------------------
# Cleanup and logging
echo "Performing cleanup..."
rm -f ${fullpath}.tar.gz
rm -rf ${fullpath}

echo "Logging the transfer..."
me=$(whoami)
echo -e "$proj_dir\t$exp_dir\t$me\t$(date)" >> ${output}/archive_log.txt

echo "Archiving complete!"
