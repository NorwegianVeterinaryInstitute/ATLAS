#!/bin/bash

## Script used to transfer data from NIRD to
## /cluster/shared/vetinst/data/wgs

address=/nird/projects/NS9305K/SEQ-TECH/data_delivery/
dest=/cluster/shared/vetinst/datasets/wgs/${2}

# Checks
## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No input csv provided."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: No output directory provided."
    exit 1
fi

## Check for output directory name structure
### Check for project_experiment_date
regex='^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{8})$'

if [[ "$2" =~ $regex ]]; then
    project="${BASH_REMATCH[1]}"
    experiment="${BASH_REMATCH[2]}"
    date_part="${BASH_REMATCH[3]}"

    # Validate the extracted date
    if ! date -d "${date_part}" +"%Y%m%d" &>/dev/null; then
        echo "Error: Invalid date. Please use a real date in YYYYMMDD format."
        exit 1
    fi
else
    # This runs only if the regex didn't match at all
    echo "Error: Input must follow the format project_experiment_date"
    echo "No underscores '_' allowed in project or experiment name"
    echo "Date has to be exactly 8 digits in the YYYYMMDD format"
    exit 1
fi

## Check if destination dir exists
if test -d $dest; then
    echo "Output directory already exists. Please choose a different name."
    exit 1
else
    echo "Creating output directory"
    mkdir $dest
    cd $dest
fi

# Get number of samples and initiate variable for counting
nsamples=$(wc -l < $1)
nreads=$(($nsamples*2))
echo "Identified" $nsamples "samples with" $nreads "readfiles"
loopcount=0

# Transfer files
echo "Transferring files..."
while IFS="," read -r name tarball
do
    # Check to see if the file is present in the tarball
    test=$(tar -tvf ${address}${tarball} | grep $name; echo $?;)
    if [[ $test == 1 ]]; then
        # Output filenames that are missing
        echo "$name,$tarball" >> missing_samples.csv
    else
        filenames=$(tar -tvf ${address}${tarball} | grep $name | grep 'fastq.gz$' | awk '{print $6}')
        for i in $filenames;
        do
            tar -xf ${address}${tarball} $i
            mv $i .
            rm -rf ${tarball%.tar}
            # Increment loopcount for each file found
            ((loopcount++))
        done
    fi
done < $1

# Check if all files were identified
if [[ $loopcount == $nreads ]]; then
    echo "All files transferred!"
else
    echo "Missing files, please check output."
fi

# Create note file in subproject
time=$(date)
user=$(whoami)
echo "Created by" $user "on" $time > info.txt
echo "Project:" $project >> info.txt
echo "Experiment:" $experiment >> info.txt
cp $1 reads.csv
