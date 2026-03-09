#!/bin/bash
# Functions used in ATLAS scripts

# Function to strip quotes from a string
strip_quotes() {
    local str="$1"
    # Remove leading and trailing quotes
    str="${str#\"}"
    str="${str%\"}"
    /usr/bin/printf "%s" "$str"
}

check_tarballs() {
    local csv_file="$1"
    local missing=0
    EXPECTED_READS=0
    local name tarball tarpath count
    local -a tarball_array

    /usr/bin/printf "Checking tarballs...\n"

    while IFS="," read -r name tarball; do
        name=$(strip_quotes "$name")
        tarball=$(strip_quotes "$tarball")

        [[ -z "$name" && -z "$tarball" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarball"

        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(/usr/bin/printf "%s" "$tarpath" | /usr/bin/xargs)

            if [[ ! -f "$tarpath" ]]; then
                /usr/bin/printf "Error: Tarball not found: %s\n" "$tarpath" >&2
                /usr/bin/printf "%s,%s\n" "$name" "$tarpath" >> missing_tarballs.csv
                missing=1
            else
                count=$(/usr/bin/tar -tvf "$tarpath" 2>/dev/null | /usr/bin/grep -c "$name.*\(fastq\.gz\|fq\.gz\)$" || echo 0)
                EXPECTED_READS=$((EXPECTED_READS + count))
            fi
        done
    done < <(/usr/bin/tail -n +2 "$csv_file")

    if [[ "$missing" -eq 1 ]]; then
        /usr/bin/printf "One or more tarballs are missing. Please fix and rerun.\n" >&2
        return 1
    fi
}

transfer_files() {
    local csv_file="$1"
    local append_mode="$2"
    local loopcount=0
    local sample_found
    local name tarball tarpath filenames i tarball_name
    local -a tarball_array

    /usr/bin/printf "Transferring files...\n"

    while IFS="," read -r name tarball; do
        name=$(strip_quotes "$name")
        tarball=$(strip_quotes "$tarball")

        [[ -z "$name" && -z "$tarball" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarball"
        sample_found=0

        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(/usr/bin/printf "%s" "$tarpath" | /usr/bin/xargs)

            if /usr/bin/tar -tvf "$tarpath" 2>/dev/null | /usr/bin/grep -q "$name"; then
                sample_found=1
                filenames=$(/usr/bin/tar -tvf "$tarpath" | /usr/bin/grep "$name" | /usr/bin/grep -E 'fastq\.gz$|fq\.gz$' | /usr/bin/awk '{print $6}')

                for i in $filenames; do
                    /usr/bin/tar -xf "$tarpath" "$i"
                    base=$(/usr/bin/basename "$i")
                    /usr/bin/mv "$i" .
                    /usr/bin/chmod 444 "$base"
                    /usr/bin/sha512sum "$base" >> sha512sums.txt
                    if $append_mode; then
                        /usr/bin/printf "%s\n" "$base" >> appended_reads.txt
                    else
                        /usr/bin/printf "%s\n" "$base" >> transferred_reads.txt
                    fi
                    tarball_name=$(/usr/bin/basename "$tarpath")
                    /usr/bin/rm -rf "${dest:?}/${tarball_name%.tar}"
                    ((loopcount++))
                done
            fi
        done

        if [[ $sample_found -eq 0 ]]; then
            /usr/bin/printf "%s,%s\n" "$name" "$tarball" >> missing_samples.csv
        fi

        if [[ ${#tarball_array[@]} -gt 1 ]]; then
            for tarpath in "${tarball_array[@]}"; do
                tarpath=$(/usr/bin/printf "%s" "$tarpath" | /usr/bin/xargs)
                if ! /usr/bin/tar -tvf "$tarpath" 2>/dev/null | /usr/bin/grep -q "$name"; then
                    /usr/bin/printf "Warning: Sample %s not found in tarball %s (but found in others)\n" "$name" "$tarpath"
                    /usr/bin/printf "%s,%s\n" "$name" "$tarpath" >> missing_in_some_tarballs.csv
                fi
            done
        fi
    done < <(/usr/bin/tail -n +2 "$csv_file")

    if [[ $loopcount -eq $EXPECTED_READS ]]; then
        /usr/bin/printf "All files transferred.\n"
    else
        /usr/bin/printf "Warning: Expected %s reads, but found %s\n" "$EXPECTED_READS" "$loopcount"
        /usr/bin/printf "Please check output for missing files.\n"
    fi
}

find_append_conflicts() {
    local input_csv="$1"
    local existing_csv="$2"

    local name tarballs tarpath key
    local found_conflicts=0
    local -a tarball_array
    declare -A existing_pairs=()
    declare -A reported_pairs=()

    # Read existing CSV
    while IFS=',' read -r name tarballs; do
        name=$(strip_quotes "$name")
        tarballs=$(strip_quotes "$tarballs")

        [[ -z "$name" && -z "$tarballs" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarballs"
        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(/usr/bin/printf "%s" "$tarpath" | /usr/bin/xargs)
            key="$name|$tarpath"
            existing_pairs["$key"]=1
        done
    done < <(/usr/bin/tail -n +2 "$existing_csv")

    # Check input CSV against existing CSV
    while IFS=',' read -r name tarballs; do
        name=$(strip_quotes "$name")
        tarballs=$(strip_quotes "$tarballs")

        [[ -z "$name" && -z "$tarballs" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarballs"
        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(/usr/bin/printf "%s" "$tarpath" | /usr/bin/xargs)
            key="$name|$tarpath"

            if [[ -n "${existing_pairs[$key]:-}" && -z "${reported_pairs[$key]:-}" ]]; then
                /usr/bin/printf '%s,%s\n' "$name" "$tarpath"
                reported_pairs["$key"]=1
                found_conflicts=1
            fi
        done
    done < <(/usr/bin/tail -n +2 "$input_csv")

    [[ $found_conflicts -eq 0 ]]
}
