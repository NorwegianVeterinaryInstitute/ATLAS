#!/bin/bash
# Functions used in ATLAS scripts

# Function to strip quotes from a string
strip_quotes() {
    local str="$1"
    # Remove leading and trailing quotes
    str="${str#\"}"
    str="${str%\"}"
    printf "%s" "$str"
}

# Print the read files in a tarball that belong to a sample, one per line.
# A read belongs to the sample when its file name (not its directory)
# contains the sample name. This substring match is deliberate: users pick
# how specific the sample name is (sample1 or sample1_L001) and must keep
# names unambiguous within a tarball. tar -tf lists names only, so owner or
# group names with spaces do not shift any columns.
list_reads() {
    local tarpath="$1"
    local name="$2"
    local f base

    /usr/bin/tar -tf "$tarpath" 2>/dev/null | while IFS= read -r f; do
        base="${f##*/}"
        if [[ "$base" == *"$name"* && "$base" =~ \.(fastq|fq)\.gz$ ]]; then
            printf "%s\n" "$f"
        fi
    done
}

check_tarballs() {
    local csv_file="$1"
    EXPECTED_READS=0
    local name tarball tarpath count
    local -a tarball_array
    local -a missing_rows=()

    printf "Checking tarballs...\n"

    while IFS="," read -r name tarball || [[ -n "$name" ]]; do
        name=$(strip_quotes "$name")
        tarball=$(strip_quotes "$tarball")

        [[ -z "$name" && -z "$tarball" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarball"

        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(printf "%s" "$tarpath" | /usr/bin/xargs)

            if [[ ! -f "$tarpath" ]]; then
                printf "Error: Tarball not found: %s\n" "$tarpath" >&2
                missing_rows+=("${name},${tarpath}")
            else
                count=$(list_reads "$tarpath" "$name" | /usr/bin/grep -c .)
                EXPECTED_READS=$((EXPECTED_READS + count))
            fi
        done
    done < <(/usr/bin/tail -n +2 "$csv_file")

    # Rewrite the report on every run so it only lists what is missing now
    if [[ ${#missing_rows[@]} -gt 0 ]]; then
        printf "%s\n" "${missing_rows[@]}" > missing_tarballs.csv
        printf "One or more tarballs are missing (listed in %s). Please fix and rerun.\n" "${PWD}/missing_tarballs.csv" >&2
        return 1
    fi
    /usr/bin/rm -f missing_tarballs.csv
}

# Report reads that would overwrite each other: a file name listed more than
# once across the CSV (two tarballs, two directories in one tarball, a sample
# listed twice, or one sample name contained in another), or a file name
# already present in dest_dir (append mode; pass "" to skip). Prints one line
# per clash and returns 1 if there are any.
find_read_clashes() {
    local csv_file="$1"
    local dest_dir="$2"
    local name tarball tarpath f base
    local found=0
    local -a tarball_array
    declare -A seen=()

    while IFS="," read -r name tarball || [[ -n "$name" ]]; do
        name=$(strip_quotes "$name")
        tarball=$(strip_quotes "$tarball")

        [[ -z "$name" && -z "$tarball" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarball"

        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(printf "%s" "$tarpath" | /usr/bin/xargs)

            while IFS= read -r f; do
                base="${f##*/}"
                if [[ -n "${seen[$base]:-}" ]]; then
                    printf "%s: in %s and %s\n" "$base" "${seen[$base]}" "${tarpath}:${f}"
                    found=1
                elif [[ -n "$dest_dir" && -e "${dest_dir}/${base}" ]]; then
                    printf "%s: already in %s\n" "$base" "$dest_dir"
                    found=1
                fi
                seen[$base]="${tarpath}:${f}"
            done < <(list_reads "$tarpath" "$name")
        done
    done < <(/usr/bin/tail -n +2 "$csv_file")

    [[ $found -eq 0 ]]
}

transfer_files() {
    local csv_file="$1"
    local append_mode="$2"
    local loopcount=0
    local sample_found
    local name tarball tarpath reads i base dir
    local -a tarball_array

    printf "Transferring files...\n"

    while IFS="," read -r name tarball || [[ -n "$name" ]]; do
        name=$(strip_quotes "$name")
        tarball=$(strip_quotes "$tarball")

        [[ -z "$name" && -z "$tarball" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarball"
        sample_found=0

        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(printf "%s" "$tarpath" | /usr/bin/xargs)

            reads=$(list_reads "$tarpath" "$name")
            if [[ -n "$reads" ]]; then
                sample_found=1

                while IFS= read -r i; do
                    /usr/bin/tar -xf "$tarpath" "$i"
                    base="${i##*/}"
                    # Reads inside a directory in the tarball: move them up
                    # and remove the directories tar created, if now empty
                    if [[ "${i#./}" == */* ]]; then
                        /usr/bin/mv "$i" .
                        dir="${i#./}"
                        /usr/bin/rmdir -p --ignore-fail-on-non-empty "${dir%/*}"
                    fi
                    /usr/bin/chmod 444 "$base"
                    /usr/bin/sha512sum "$base" >> sha512sums.txt
                    if $append_mode; then
                        printf "%s\n" "$base" >> appended_reads.txt
                    else
                        printf "%s\n" "$base" >> transferred_reads.txt
                    fi
                    ((loopcount++))
                done <<< "$reads"
            fi
        done

        if [[ $sample_found -eq 0 ]]; then
            printf "%s,%s\n" "$name" "$tarball" >> missing_samples.csv
        fi

        if [[ ${#tarball_array[@]} -gt 1 ]]; then
            for tarpath in "${tarball_array[@]}"; do
                tarpath=$(printf "%s" "$tarpath" | /usr/bin/xargs)
                if [[ -z "$(list_reads "$tarpath" "$name")" ]]; then
                    printf "Warning: Sample %s not found in tarball %s (but found in others)\n" "$name" "$tarpath"
                    printf "%s,%s\n" "$name" "$tarpath" >> missing_in_some_tarballs.csv
                fi
            done
        fi
    done < <(/usr/bin/tail -n +2 "$csv_file")

    if [[ $loopcount -eq $EXPECTED_READS ]]; then
        printf "All files transferred.\n"
    else
        printf "Warning: Expected %s reads, but found %s\n" "$EXPECTED_READS" "$loopcount"
        printf "Please check output for missing files.\n"
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
    while IFS=',' read -r name tarballs || [[ -n "$name" ]]; do
        name=$(strip_quotes "$name")
        tarballs=$(strip_quotes "$tarballs")

        [[ -z "$name" && -z "$tarballs" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarballs"
        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(printf "%s" "$tarpath" | /usr/bin/xargs)
            key="$name|$tarpath"
            existing_pairs["$key"]=1
        done
    done < <(/usr/bin/tail -n +2 "$existing_csv")

    # Check input CSV against existing CSV
    while IFS=',' read -r name tarballs || [[ -n "$name" ]]; do
        name=$(strip_quotes "$name")
        tarballs=$(strip_quotes "$tarballs")

        [[ -z "$name" && -z "$tarballs" ]] && continue

        IFS=',' read -ra tarball_array <<< "$tarballs"
        for tarpath in "${tarball_array[@]}"; do
            tarpath=$(printf "%s" "$tarpath" | /usr/bin/xargs)
            key="$name|$tarpath"

            if [[ -n "${existing_pairs[$key]:-}" && -z "${reported_pairs[$key]:-}" ]]; then
                printf '%s,%s\n' "$name" "$tarpath"
                reported_pairs["$key"]=1
                found_conflicts=1
            fi
        done
    done < <(/usr/bin/tail -n +2 "$input_csv")

    [[ $found_conflicts -eq 0 ]]
}

# Link every read file (*.fastq.gz, *.fq.gz) in src_dir into dst_dir.
# Reads that are already linked are skipped, so append mode can link the
# whole directory again. Any other failure to link is an error.
link_reads() {
    local src_dir="$1"
    local dst_dir="$2"
    local f
    local failed=0

    for f in "$src_dir"/*.fastq.gz "$src_dir"/*.fq.gz; do
        # An unmatched glob stays literal
        [[ -e "$f" ]] || continue
        [[ -L "${dst_dir}/${f##*/}" ]] && continue
        /usr/bin/ln -s "$f" "$dst_dir/" || failed=1
    done

    return "$failed"
}
