# Functions used in ATLAS scripts

# Function to strip quotes from a string
strip_quotes() {
    local str="$1"
    # Remove leading and trailing quotes
    str="${str#\"}"
    str="${str%\"}"
    echo "$str"
}

check_tarballs() {
    local csv_file="$1"
    local missing=0
    EXPECTED_READS=0
    local name tarball tarpath count
    local -a tarball_array

    echo "Checking tarballs..."

    while IFS="," read -r name tarball; do
        name=$(strip_quotes "$name")
        tarball=$(strip_quotes "$tarball")

        [[ -z "$name" && -z "$tarball" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarball"

        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(echo "$tarpath" | xargs)

            if [[ ! -f "$tarpath" ]]; then
                echo "Error: Tarball not found: $tarpath" >&2
                echo "$name,$tarpath" >> missing_tarballs.csv
                missing=1
            else
                count=$(tar -tvf "$tarpath" 2>/dev/null | grep -c "$name.*\(fastq\.gz\|fq\.gz\)$" || echo 0)
                EXPECTED_READS=$((EXPECTED_READS + count))
            fi
        done
    done < <(tail -n +2 "$csv_file")

    if [[ "$missing" -eq 1 ]]; then
        echo "One or more tarballs are missing. Please fix and rerun." >&2
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

    echo "Transferring files..."

    while IFS="," read -r name tarball; do
        name=$(strip_quotes "$name")
        tarball=$(strip_quotes "$tarball")

        [[ -z "$name" && -z "$tarball" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarball"
        sample_found=0

        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(echo "$tarpath" | xargs)

            if tar -tvf "$tarpath" 2>/dev/null | grep -q "$name"; then
                sample_found=1
                filenames=$(tar -tvf "$tarpath" | grep "$name" | grep -E 'fastq\.gz$|fq\.gz$' | awk '{print $6}')

                for i in $filenames; do
                    tar -xf "$tarpath" "$i"
                    base=$(basename "$i")
                    mv "$i" .
                    chmod 444 "$base"
                    sha512sum "$base" >> sha512sums.txt
                    if $append_mode; then
                        echo "$base" >> appended_reads.txt
                    else
                        echo "$base" >> transferred_reads.txt
                    fi
                    tarball_name=$(basename "$tarpath")
                    rm -rf "${dest:?}/${tarball_name%.tar}"
                    ((loopcount++))
                done
            fi
        done

        if [[ $sample_found -eq 0 ]]; then
            echo "$name,$tarball" >> missing_samples.csv
        fi

        if [[ ${#tarball_array[@]} -gt 1 ]]; then
            for tarpath in "${tarball_array[@]}"; do
                tarpath=$(echo "$tarpath" | xargs)
                if ! tar -tvf "$tarpath" 2>/dev/null | grep -q "$name"; then
                    echo "Warning: Sample $name not found in tarball $tarpath (but found in others)"
                    echo "$name,$tarpath" >> missing_in_some_tarballs.csv
                fi
            done
        fi
    done < <(tail -n +2 "$csv_file")

    if [[ $loopcount -eq $EXPECTED_READS ]]; then
        echo "All files transferred."
    else
        echo "Warning: Expected $ reads, but found $loopcount"
        echo "Please check output for missing files."
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
            tarpath=$(echo "$tarpath" | xargs)
            key="$name|$tarpath"
            existing_pairs["$key"]=1
        done
    done < <(tail -n +2 "$existing_csv")

    # Check input CSV against existing CSV
    while IFS=',' read -r name tarballs; do
        name=$(strip_quotes "$name")
        tarballs=$(strip_quotes "$tarballs")

        [[ -z "$name" && -z "$tarballs" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarballs"
        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(echo "$tarpath" | xargs)
            key="$name|$tarpath"

            if [[ -n "${existing_pairs[$key]:-}" && -z "${reported_pairs[$key]:-}" ]]; then
                printf '%s,%s\n' "$name" "$tarpath"
                reported_pairs["$key"]=1
                found_conflicts=1
            fi
        done
    done < <(tail -n +2 "$input_csv")

    [[ $found_conflicts -eq 0 ]]
}
