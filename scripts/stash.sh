#!/bin/bash

set -e

# Script for stashing experiments

# --------------------------------------------------
# Get input and set variables
stash=false
unstash=false

for arg in "$@"; do
    case "$arg" in
        --stash) stash=true; shift ;;
        --unstash) unstash=true; shift ;;
        *) break ;;
    esac
done

exp_dir=$1
proj_dir=$2
me=$(whoami)

# General checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No experiment directory name provided."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: No project directory name provided."
    exit 1
fi

if $stash; then
    output=/nird/datalake/NS9305K/archive/experiment_stash
    proj_loc=/cluster/projects/nn9305k/development/projects
    proj_fullpath=${proj_loc}/${proj_dir}
    fullpath=${proj_loc}/${proj_dir}/${exp_dir}

    # Checks
    ## Check if dirs exist
    if ! test -d $proj_fullpath; then
        echo "Supplied project directory does not exist."
        exit 1
    fi

    if ! test -d $fullpath; then
        echo "Supplied experiment directory does not exist."
        exit 1
    fi

    ## Check if experiment exists in stash
    if [[ -d ${output}/${exp_dir}.tar.gz ]]; then
        echo "Experiment already stashed. Please verify name of the experiment."
        exit 1
    fi

    # --------------------------------------------------
    # Create experiment tarball
    echo "All checks passed, creating tarball and stashing..."
    echo "Stashed by $me on $(date)" >> ${fullpath}/stash_log.txt

    cd $proj_fullpath
    tar -czf ${exp_dir}.tar.gz $exp_dir

    # Verify tarball archive
    echo "Verifying archive..."
    if tar -tzf ${exp_dir}.tar.gz > /dev/null; then
        echo "Archive verification successful!"
    else
        echo "Error: Archive verification failed. Deleting corrupt archive."
        rm -f ${exp_dir}.tar.gz
        exit 1
    fi

    # --------------------------------------------------
    # Get checksum of archive
    echo "Creating checksum of archive..."
    hash_pre=$(sha512sum ${exp_dir}.tar.gz | awk '{print $1}')

    # --------------------------------------------------
    # Transfer tarball to storage
    echo "Moving archive to NIRD..."
    rsync -avPW ${exp_dir}.tar.gz $output

    # --------------------------------------------------
    # Check tarball checksum after transfer
    echo "Verifying checksum after transfer..."
    hash_post=$(sha512sum ${output}/${exp_dir}.tar.gz | awk '{print $1}')

    if [[ "$hash_pre" == "$hash_post" ]]; then
        echo "Checksums are equal, stashing complete!"
    else
        echo "Error: Checksums not equal. Please check files manually."
        rm -f ${output}/${exp_dir}.tar.gz
        exit 1
    fi
    # --------------------------------------------------
    # Log the stashing and cleanup
    echo -e "$proj_dir\t$exp_dir\t$me\t$(date)" >> ${output}/stash_log.txt
    rm -rf ${fullpath}
    rm -f ${fullpath}.tar.gz

elif $unstash; then
    input=/nird/datalake/NS9305K/archive/experiment_stash
    proj_loc=/cluster/projects/nn9305k/development/projects
    proj_fullpath=${proj_loc}/${proj_dir}
    fullpath=${proj_fullpath}/${exp_dir}

    echo "Unstashing tarball and transferring to Saga..."
    # Get checksum before transfer
    hash_pre=$(sha512sum ${input}/${exp_dir}.tar.gz | awk '{print $1}')

    # Transfer file
    rsync -avPW ${input}/${exp_dir}.tar.gz $proj_fullpath

    # Verify checksum
    echo "Verifying checksum after transfer..."
    hash_post=$(sha512sum ${fullpath}.tar.gz | awk '{print $1}')

    if [[ "$hash_pre" == "$hash_post" ]]; then
        echo "Checksums are equal, transfer complete!"
    else
        echo "Error: Checksums not equal. Please check files manually."
        rm -f ${fullpath}.tar.gz
        exit 1
    fi

    # Unpack tarball
    echo "Unpacking experiment..."
    cd $proj_fullpath
    tar -xzf ${exp_dir}.tar.gz
    echo "Unstashed by $me on $(date)" >> ${exp_dir}/stash_log.txt

    # Cleanup
    rm -f ${input}/${exp_dir}.tar.gz
    rm -f ${exp_dir}.tar.gz
    echo -e "$proj_dir\t$exp_dir\t$me\t$(date)" >> ${input}/unstash_log.txt

    echo "Unstashing complete!"
else
    "Error: You must specify either --stash or --unstash"
    exit 1
fi
