#!/bin/bash

## Script used to transfer data from NIRD to
## /cluster/shared/vetinst/active_data

# Help function
show_help() {
    cat << EOF
Usage: activate_data.sh INPUT_CSV OUTPUT_DIR

Transfer data from NIRD to /cluster/shared/vetinst/active_data.

ARGUMENTS:
    INPUT_CSV      Path to CSV file containing sample names and tarball paths
    OUTPUT_DIR     Output directory name in format: project_study_YYYYMMDD

DESCRIPTION:
    This script performs the following operations:
    - Validates the CSV file and checks for tarball presence
    - Creates the output directory at /cluster/shared/vetinst/active_data/OUTPUT_DIR
    - Extracts FASTQ files from tarballs specified in the CSV
    - Sets files to read-only (chmod 444)
    - Generates SHA512 checksums for all files
    - Creates metadata files (info.txt, reads.csv)

    The output directory name must follow the format: project_study_YYYYMMDD
    - No underscores allowed in project or study name parts
    - Date must be exactly 8 digits in YYYYMMDD format
    - Date must be a valid date

    CSV format: sample_name,/path/to/tarball.tar

EXAMPLE:
    activate_data.sh samples.csv MyProj_Study1_20231120

EOF
    exit 0
}

# Checks
## Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

## Check for user-supplied parameters
if [ -z "$1" ]; then
    echo "Error: No input csv provided."
    echo "Use -h or --help for usage information."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: No output directory provided."
    echo "Use -h or --help for usage information."
    exit 1
fi

# Get input and set variables
csv=$(realpath "$1")
dest=/cluster/shared/vetinst/active_data/${2}

## Check for output directory name structure
### Check for project_study_date
regex='^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{8})$'

if [[ "$2" =~ $regex ]]; then
    project="${BASH_REMATCH[1]}"
    study="${BASH_REMATCH[2]}"
    date_part="${BASH_REMATCH[3]}"

    # Validate the extracted date
    if ! date -d "${date_part}" +"%Y%m%d" &>/dev/null; then
        echo "Error: Invalid date. Please use a real date in YYYYMMDD format."
        exit 1
    fi
else
    # This runs only if the regex didn't match at all
    echo "Error: Input must follow the format project_study_date"
    echo "No underscores '_' allowed in project or study name"
    echo "Date has to be exactly 8 digits in the YYYYMMDD format"
    exit 1
fi

## Check if destination dir exists
if test -d "$dest"; then
    echo "Output directory already exists. Please choose a different name."
    exit 1
else
    echo "Creating output directory"
    mkdir "$dest"
    cd "$dest" || exit
fi

# Function to strip quotes from a string
strip_quotes() {
    local str="$1"
    # Remove leading and trailing quotes
    str="${str#\"}"
    str="${str%\"}"
    echo "$str"
}

# Check tarball presence
dos2unix -q "$csv"
echo "Checking tarballs..."
missing=0
expected_readsets=0

while IFS="," read -r name tarball
do
    # Strip quotes from both fields
    name=$(strip_quotes "$name")
    tarball=$(strip_quotes "$tarball")
    
    # Skip empty lines
    if [[ -z "$name" && -z "$tarball" ]]; then
        continue
    fi
    
    # Split tarball field by comma to handle multiple tarballs
    IFS=',' read -ra tarball_array <<< "$tarball"
    
    for tarpath in "${tarball_array[@]}"; do
        # Trim whitespace
        tarpath=$(echo "$tarpath" | xargs)
        
        if [[ ! -f "$tarpath" ]]; then
            echo "Error: Tarball not found: $tarpath"
            echo "$name,$tarpath" >> missing_tarballs.csv
            missing=1
        else
            # Count expected read sets from this tarball for this sample
            # Each sample typically has R1 and R2 files
            count=$(tar -tvf "$tarpath" 2>/dev/null | grep -c "$name.*\(fastq\.gz\|fq\.gz\)$" || echo 0)
            expected_readsets=$((expected_readsets + count))
        fi
    done
done < "$csv"

if [[ $missing -eq 1 ]]; then
    echo "One or more tarballs are missing. Please fix and rerun."
    exit 1
fi

echo "All tarballs found. Starting transfer..."
echo "Expected read sets: $expected_readsets"
loopcount=0

# Transfer files
echo "Transferring files..."
while IFS="," read -r name tarball
do
    # Strip quotes from both fields
    name=$(strip_quotes "$name")
    tarball=$(strip_quotes "$tarball")
    
    # Skip empty lines
    if [[ -z "$name" && -z "$tarball" ]]; then
        continue
    fi
    
    # Split tarball field by comma to handle multiple tarballs
    IFS=',' read -ra tarball_array <<< "$tarball"
    
    # Track if sample was found in at least one tarball
    sample_found=0
    
    for tarpath in "${tarball_array[@]}"; do
        # Trim whitespace
        tarpath=$(echo "$tarpath" | xargs)
        
        # Check to see if the file is present in the tarball
        if tar -tvf "$tarpath" 2>/dev/null | grep -q "$name"; then
            sample_found=1
            filenames=$(tar -tvf "$tarpath" | grep "$name" | grep -e 'fastq.gz$' -e "fq.gz$" | awk '{print $6}')
            for i in $filenames;
            do
                tar -xf "$tarpath" "$i"
                mv "$i" .
                chmod 444 "$(basename "$i")"
                sha512sum "$(basename "$i")" >> sha512sums.txt
                rm -rf "${tarpath%.tar}"
                # Increment loopcount for each file found
                ((loopcount++))
            done
        fi
    done
    
    # If sample was not found in any tarball, report it
    if [[ $sample_found -eq 0 ]]; then
        echo "$name,$tarball" >> missing_samples.csv
    fi
    
    # Verify sample exists in all specified tarballs (if multiple)
    if [[ ${#tarball_array[@]} -gt 1 ]]; then
        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(echo "$tarpath" | xargs)
            if ! tar -tvf "$tarpath" 2>/dev/null | grep -q "$name"; then
                echo "Warning: Sample $name not found in tarball $tarpath (but found in others)"
                echo "$name,$tarpath" >> missing_in_some_tarballs.csv
            fi
        done
    fi
done < "$csv"

# Check if all files were identified
if [[ $loopcount -eq $expected_readsets ]]; then
    echo "All files transferred."
else
    echo "Warning: Expected $expected_readsets read sets, but found $loopcount"
    echo "Please check output for missing files."
fi

# Create note file in subproject
time=$(date)
user=$(whoami)
echo "Created by" "$user" "on" "$time" > info.txt
echo "Project:" "$project" >> info.txt
echo "Study: study_$2" >> info.txt
cp "$csv" reads.csv

echo "Data activated!"
