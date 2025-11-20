#!/bin/bash

set -e

# Script for archiving studies.
# The script will create a tarball of the
# study directory, and transfer the
# tarball to the correct location on NIRD.

# Help function
show_help() {
    cat << EOF
Usage: archive_study.sh STUDY_DIR PROJECT_DIR

Archive a study by creating a tarball and transferring it to NIRD storage.

ARGUMENTS:
    STUDY_DIR      Name of the study directory to archive
    PROJECT_DIR    Name of the project directory containing the study

DESCRIPTION:
    This script performs the following operations:
    - Checks if the study directory exists and meets requirements
    - Warns if directory size exceeds 250GB
    - Verifies that sandbox directory has been removed
    - Verifies that results and data directories are present
    - Creates a tarball of the study directory
    - Verifies the tarball integrity
    - Transfers the archive to NIRD (/nird/datalake/NS9305K/study_archive)
    - Verifies checksums before and after transfer
    - Removes the original study directory after successful archiving
    - Logs the archiving operation

REQUIREMENTS:
    - Sandbox directory must be removed before archiving
    - Results directory must be present
    - Data directory must be present

EXAMPLE:
    archive_study.sh study_mydata_20231120 myproject

EOF
    exit 0
}

# --------------------------------------------------
# Checks
## Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# --------------------------------------------------
# Get input and set variables
study_dir=$1
proj_dir=$2
proj_loc=/cluster/projects/nn9305k/projects
proj_fullpath=${proj_loc}/${proj_dir}
fullpath=${proj_loc}/${proj_dir}/${study_dir}
data_dir=/cluster/shared/vetinst/active_data
output=/nird/datalake/NS9305K/study_archive

# --------------------------------------------------
# Checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No study directory name provided."
    echo "Use -h or --help for usage information."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: No project directory name provided."
    echo "Use -h or --help for usage information."
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

## Check directory size
size_kb=$(du -s "$fullpath" | awk '{print $1}')
size_mb=$((size_kb / 1024))
size_gb=$((size_mb / 1024))

threshold=250

if (( size_gb > threshold )); then
    echo "Warning: Experiment directory '$study_dir' is very large (~${size_gb}GB)."
    echo "Please consider removing additional redundant or intermediary files."
    read -p "Continue archiving anyway? (y/n): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        echo "Archiving cancelled."
        exit 1
    fi
fi

# Check for presence of specific directories
## Check if sandbox archive is removed
if [[ -d "$fullpath/sandbox" ]]; then
    echo "The sandbox directory is still present in the study."
    echo "Please delete it before archiving."
    exit 1
fi

if [[ ! -d "$fullpath/results" ]]; then
    echo "The results directory is not present in the study."
    echo "Please make sure to uphold the directory structure of studies."
    echo "Stopping the archiving process."
    exit 1
fi

if [[ ! -d "$fullpath/data" ]]; then
    echo "The data directory is not present in the study."
    echo "Please make sure to uphold the directory structure of studies."
    echo "Stopping the archiving process."
    exit 1
fi

## Check if experiment exists in the archive
if [[ -d ${output}/${exp_dir}.tar.gz ]]; then
    echo "Study already archived. Please verify name of the study."
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
hash_post=$(sha512sum ${output}/${study_dir}.tar.gz | awk '{print $1}')

if [[ "$hash_pre" == "$hash_post" ]]; then
    echo "Checksums are equal, transfer complete!"
else
    echo "Error: Checksums not equal. Please check files manually."
    rm -f ${output}/${study_dir}.tar.gz
    exit 1
fi

# --------------------------------------------------
# Cleanup and logging
echo "Performing cleanup..."
chmod 444 ${output}/${study_dir}.tar.gz
rm -f ${fullpath}.tar.gz
rm -rf ${fullpath}
rm -rf ${data_dir}/${study_dir##study_}

echo "Logging the transfer..."
me=$(whoami)
echo $study_dir "archived by" $me "on $(date)" >> ${proj_fullpath}/archive_log.txt
echo -e "$proj_dir\t$study_dir\t$me\t$(date)" >> ${output}/archive_log.txt

echo "Archiving complete!"
