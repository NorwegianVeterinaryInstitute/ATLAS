#!/bin/bash

address=/nird/projects/NS9305K/SEQ-TECH/data_delivery/
dest=/cluster/shared/vetinst/datasets/wgs/${2}

# Check for user-supplied parameters
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
fi

# Check if destination dir exists
if test -d $dest; then
    echo "Output directory already exists. Please choose a different name."
    exit 1
else
    mkdir $dest
    cd $dest
fi

# Get project and experiment names
project=$(echo ${2%%_*})

# Get number of samples and initiate variable for counting
nsamples=$(wc -l < $1)
nreads=$(($nsamples*2))
echo "Identified " $nsamples " samples with " $nreads " readfiles."
loopcount=0

# Transfer files
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
            tar -xvf ${address}${tarball} $i
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
echo "Created by " $user " on " $time "." > info.txt
echo "Project: " $project >> info.txt
cp $1 samples.csv
