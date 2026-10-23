#!/bin/bash

# End-to-end test for the ATLAS scripts.
# Builds a throwaway directory tree with dummy tarballs and FASTQ files,
# writes a config pointing at it, and runs the full lifecycle:
# create_project -> activate_data -> create_study -> append ->
# freeze -> thaw -> archive, plus a few expected-failure cases.
#
# Reading the output
#   Each line is "ok" or "FAIL" followed by a description. A failing step
#   also prints the script's output. Every step's output is saved in
#   <test dir>/logs/NN.log (numbered in run order); use -k to keep them.
#
# How the tests work
#   step   runs an ATLAS script and compares its exit code with the expected
#          one. The third argument is typed in answer to prompts ("y\n").
#   check  asserts something about the files on disk afterwards.
#   All steps run from inside the test directory and share one tree, in
#   order: later steps depend on earlier ones. When several things fail,
#   fix the first FAIL first.
#   The script does not use set -e on purpose: it keeps going after a
#   failure so that every result is reported.
#
# Adding a test case
#   step  "refuses X" 1 "" bash "${SCRIPTS}/some_script.sh" -p "$PROJ"
#   check "file Y exists" test -f "${PROJ_DIR}/${PROJ}/Y"

# Help function
show_help() {
    cat << EOF
Usage: e2e.sh [-d BASE_DIR] [-k] [-v] [-h]

Run the ATLAS scripts end to end against dummy data in a temporary directory.

ARGUMENTS:
    -d BASE_DIR  Directory to create the test directory in (default: \$TMPDIR or /tmp).
                 On systems where /tmp is not writable (e.g. Saga), use a
                 directory you own: -d ~/tmp
    -k    Keep the temporary directory after the run (for inspection)
    -v    Print the output of every step, not only failing ones
    -h    Show this help message

REQUIREMENTS:
    The tools checked by scripts/check_dependencies.sh
    Run as a non-root user (root ignores the read-only file permissions
    that the test checks).

EXAMPLE:
    tests/e2e.sh -k
    tests/e2e.sh -d ~/tmp -k

EOF
}

keep=false
verbose=false
base_dir="${TMPDIR:-/tmp}"

while getopts ":hkvd:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        k)
            keep=true
            ;;
        v)
            verbose=true
            ;;
        d)
            base_dir="$OPTARG"
            ;;
        :)
            printf "Option -%s requires an argument.\n" "$OPTARG" >&2
            exit 1
            ;;
        \?)
            printf "Invalid option: -%s\n" "$OPTARG" >&2
            exit 1
            ;;
    esac
done

REPO_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.." && pwd -P)"
SCRIPTS="${REPO_DIR}/scripts"

# Root can write to read-only files, so the read-only check would fail
if [[ "$EUID" -eq 0 ]]; then
    printf "Run as a non-root user.\n" >&2
    exit 1
fi

# Stop early if a tool the ATLAS scripts need is missing
if ! deps_out="$(bash "${SCRIPTS}/check_dependencies.sh" 2>&1)"; then
    printf "%s\n" "$deps_out" >&2
    exit 1
fi

mkdir -p "$base_dir" || { printf "Cannot create base directory: %s\n" "$base_dir" >&2; exit 1; }
ROOT="$(mktemp -d "${base_dir}/atlas-e2e.XXXXXX")" || {
    printf "Cannot create a test directory in %s. Use -d with a writable directory, e.g. -d ~/tmp\n" "$base_dir" >&2
    exit 1
}
LOGS="${ROOT}/logs"

cleanup() {
    if $keep; then
        printf "\nTest directory kept at: %s\n" "$ROOT"
    else
        chmod -R u+w "$ROOT" 2>/dev/null
        rm -rf "${ROOT:?}"
    fi
}
trap cleanup EXIT

# Setup
## Directory layout
PROJ_DIR="${ROOT}/projects"
ACTIVE_DATA_DIR="${ROOT}/active_data"
FREEZE_DIR="${ROOT}/freezer"
ARCHIVE_DIR="${ROOT}/archive"
TEMPLATE_DIR="${ROOT}/templates"
RAW_DIR="${ROOT}/raw"
mkdir -p "$PROJ_DIR" "$ACTIVE_DATA_DIR" "$FREEZE_DIR" "$ARCHIVE_DIR" \
    "$TEMPLATE_DIR" "$RAW_DIR" "$LOGS"

## Config
export ATLAS_CONFIG="${ROOT}/config.sh"
cat > "$ATLAS_CONFIG" << EOF
PROJ_DIR="${PROJ_DIR}"
ACTIVE_DATA_DIR="${ACTIVE_DATA_DIR}"
FREEZE_DIR="${FREEZE_DIR}"
ARCHIVE_DIR="${ARCHIVE_DIR}"
TEMPLATE_DIR="${TEMPLATE_DIR}"
ARCHIVE_SIZE_THRESHOLD_GB="250"
EOF

## Templates
printf "Project README template\n" > "${TEMPLATE_DIR}/project_readme.txt"
printf "Study README template\n" > "${TEMPLATE_DIR}/study_readme.txt"

## Dummy tarballs: <run>.tar containing <run>/<sample>_R{1,2}.<READ_EXT>,
## where READ_EXT defaults to fastq.gz.
## run1: sampleA, sampleB. run2: sampleC. run3: sampleD.
## run5: sampleE, sampleF as .fq.gz (#71).
make_tarball() {
    local run="$1"; shift
    local sample
    mkdir -p "${RAW_DIR}/${run}"
    for sample in "$@"; do
        printf "@%s_read1\nACGTACGTAC\n+\nIIIIIIIIII\n" "$sample" | gzip > "${RAW_DIR}/${run}/${sample}_R1.${READ_EXT:-fastq.gz}"
        printf "@%s_read1\nTGCATGCATG\n+\nIIIIIIIIII\n" "$sample" | gzip > "${RAW_DIR}/${run}/${sample}_R2.${READ_EXT:-fastq.gz}"
    done
    tar -cf "${RAW_DIR}/${run}.tar" -C "$RAW_DIR" "$run"
    rm -rf "${RAW_DIR:?}/${run}"
}

make_tarball run1 sampleA sampleB
make_tarball run2 sampleC
make_tarball run3 sampleD
READ_EXT=fq.gz make_tarball run5 sampleE sampleF
## run4 tests sample name matching (#69). Its group name has a space, as in
## tarballs made on a domain-joined machine, which used to shift the columns
## of `tar -tvf`. s.1 must not match sX1 (no regex); sample1 matches sample10
## (substring matching is deliberate); "my sample" has a space in its name.
mkdir -p "${RAW_DIR}/run4"
for sample in s.1 sX1 sample1 sample10 "my sample"; do
    printf "@r\nACGT\n+\nIIII\n" | gzip > "${RAW_DIR}/run4/${sample}_R1.fastq.gz"
done
tar -cf "${RAW_DIR}/run4.tar" --owner=atlas:1000 --group='domain users:100' -C "$RAW_DIR" run4
rm -rf "${RAW_DIR:?}/run4"

## Input CSVs. sampleB is quoted to test quote stripping; missing.csv points
## at a tarball that does not exist.
printf 'sample,tarball\nsampleA,%s\n"sampleB","%s"\n' \
    "${RAW_DIR}/run1.tar" "${RAW_DIR}/run1.tar" > "${ROOT}/study1.csv"
printf 'sample,tarball\nsampleC,%s\n' "${RAW_DIR}/run2.tar" > "${ROOT}/study1_append.csv"
## study2.csv has its own header names, headerless.csv has none (#77)
printf 'Sample ID,Tarball path\nsampleD,%s\n' "${RAW_DIR}/run3.tar" > "${ROOT}/study2.csv"
printf 'sampleD,%s\n' "${RAW_DIR}/run3.tar" > "${ROOT}/headerless.csv"
printf 'sample,tarball\n"",""\n' > "${ROOT}/no_samples.csv"
printf 'sample,tarball\nsampleX,%s\n' "${RAW_DIR}/missing.tar" > "${ROOT}/missing.csv"
## Saved as Excel or a text editor may save it: CRLF line endings and no
## newline after the last row (#70). The copy checks that the input file is
## left untouched (#81).
printf 'sample,tarball\r\nsampleA,%s\r\nsampleB,%s' \
    "${RAW_DIR}/run1.tar" "${RAW_DIR}/run1.tar" > "${ROOT}/no_newline.csv"
cp "${ROOT}/no_newline.csv" "${ROOT}/no_newline.orig"
printf 'sample,tarball\nsampleE,%s\n' "${RAW_DIR}/run5.tar" > "${ROOT}/fq.csv"
printf 'sample,tarball\nsampleF,%s\n' "${RAW_DIR}/run5.tar" > "${ROOT}/fq_append.csv"
printf 'sample,tarball\ns.1,%s\nsample1,%s\nmy sample,%s\n' \
    "${RAW_DIR}/run4.tar" "${RAW_DIR}/run4.tar" "${RAW_DIR}/run4.tar" > "${ROOT}/matching.csv"

## Configs with a missing freezer or archive directory (#72). Later
## assignments win.
{ cat "$ATLAS_CONFIG"; printf 'FREEZE_DIR="%s"\n' "${ROOT}/no_freezer"; } > "${ROOT}/config_no_freezer.sh"
{ cat "$ATLAS_CONFIG"; printf 'ARCHIVE_DIR="%s"\n' "${ROOT}/no_archive"; } > "${ROOT}/config_no_archive.sh"

# Test helpers
pass=0
fail=0
step_no=0
failed_steps=()

# step DESCRIPTION EXPECTED_RC STDIN CMD [ARGS...]
step() {
    local desc="$1" expected="$2" input="$3"; shift 3
    local log rc
    step_no=$((step_no + 1))
    log="${LOGS}/$(printf "%02d" "$step_no").log"

    (cd "$ROOT" && printf "%b" "$input" | "$@") > "$log" 2>&1
    rc=$?

    if [[ "$rc" -eq "$expected" ]]; then
        printf "  ok    %s\n" "$desc"
        pass=$((pass + 1))
        $verbose && sed 's/^/        | /' "$log"
    else
        printf "  FAIL  %s (exit %d, expected %d)\n" "$desc" "$rc" "$expected"
        sed 's/^/        | /' "$log"
        fail=$((fail + 1))
        failed_steps+=("$desc")
    fi
}

# check DESCRIPTION TEST-EXPRESSION...
# The command's own output is discarded; only ok/FAIL is printed.
check() {
    local desc="$1"; shift
    if "$@" > /dev/null 2>&1; then
        printf "  ok    %s\n" "$desc"
        pass=$((pass + 1))
    else
        printf "  FAIL  %s\n" "$desc"
        fail=$((fail + 1))
        failed_steps+=("$desc")
    fi
}

count_files() {
    find "$1" -maxdepth 1 -name "$2" 2>/dev/null | wc -l
}

PROJ="12345_TestProj"
DS1="TestProj_studyone_20240115"
DS2="TestProj_studytwo_20240116"
STUDY1="study_${DS1}"
STUDY2="study_${DS2}"
DS3="TestProj_nonewline_20240117"
STUDY3="study_${DS3}"
DS4="TestProj_fqreads_20240119"
STUDY4="study_${DS4}"

# Tests
printf "ATLAS end-to-end test\nWorking in %s\n" "$ROOT"

# Dependency check: a script calling a tool that does not exist
printf "\ncheck_dependencies.sh\n"
mkdir -p "${ROOT}/depcheck"
cp "${SCRIPTS}/check_dependencies.sh" "${ROOT}/depcheck/"
printf '#!/bin/bash\n/usr/bin/atlas-no-such-tool\n' > "${ROOT}/depcheck/fake_script.sh"
step "fails on missing tool" 1 "" bash "${ROOT}/depcheck/check_dependencies.sh"
check "lists missing tool" bash -c "bash '${ROOT}/depcheck/check_dependencies.sh' | grep -q 'missing  */usr/bin/atlas-no-such-tool'"

# Project creation: name validation, template copy, no overwrite
printf "\ncreate_project.sh\n"
step "rejects name without underscore" 1 "" bash "${SCRIPTS}/create_project.sh" -p BadName
step "creates project" 0 "" bash "${SCRIPTS}/create_project.sh" -p "$PROJ"
check "project README copied" test -f "${PROJ_DIR}/${PROJ}/README.txt"
check "creation.txt written" test -f "${PROJ_DIR}/${PROJ}/creation.txt"
step "refuses existing project" 1 "" bash "${SCRIPTS}/create_project.sh" -p "$PROJ"

# Data activation: input validation, missing-tarball report (#50),
# extraction, read-only files, checksums, no overwrite
printf "\nactivate_data.sh\n"
step "rejects bad output dir name" 1 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/study1.csv" -d bad_name
step "rejects invalid date" 1 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/study1.csv" -d TestProj_x_20241399
step "fails on missing tarball" 1 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/missing.csv" -d TestProj_missing_20240101
step "fails again on missing tarball" 1 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/missing.csv" -d TestProj_missing_20240101
check "missing_tarballs.csv lists only current run" test "$(grep -c . "${ROOT}/missing_tarballs.csv")" -eq 1
step "activates study one" 0 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/study1.csv" -d "$DS1"
check "missing_tarballs.csv removed once all found" test ! -e "${ROOT}/missing_tarballs.csv"
check "4 fastq files extracted" test "$(count_files "${ACTIVE_DATA_DIR}/${DS1}" '*.fastq.gz')" -eq 4
check "fastq files are read-only" test -f "${ACTIVE_DATA_DIR}/${DS1}/sampleA_R1.fastq.gz" -a ! -w "${ACTIVE_DATA_DIR}/${DS1}/sampleA_R1.fastq.gz"
check "sha512sums verify" bash -c "cd '${ACTIVE_DATA_DIR}/${DS1}' && sha512sum -c --quiet sha512sums.txt"
check "tarball scratch dir removed" test ! -d "${ACTIVE_DATA_DIR}/${DS1}/run1"
step "refuses existing output dir" 1 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/study1.csv" -d "$DS1"
step "activates study two" 0 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/study2.csv" -d "$DS2"
check "custom header skipped (2 fastq)" test "$(count_files "${ACTIVE_DATA_DIR}/${DS2}" '*.fastq.gz')" -eq 2
step "activates CSV without header" 0 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/headerless.csv" -d TestProj_noheader_20240118
check "first row of headerless CSV kept (2 fastq)" test "$(count_files "${ACTIVE_DATA_DIR}/TestProj_noheader_20240118" '*.fastq.gz')" -eq 2
check "data.csv gets the standard header" test "$(head -n 1 "${ACTIVE_DATA_DIR}/TestProj_noheader_20240118/data.csv")" = "sample,tarball"
step "fails on missing CSV" 1 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/nope.csv" -d TestProj_nocsv_20240101
check "no output dir for missing CSV" test ! -d "${ACTIVE_DATA_DIR}/TestProj_nocsv_20240101"
step "fails on CSV without samples" 1 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/no_samples.csv" -d TestProj_nosamples_20240101
check "no output dir for CSV without samples" test ! -d "${ACTIVE_DATA_DIR}/TestProj_nosamples_20240101"
step "activates CSV without trailing newline" 0 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/no_newline.csv" -d "$DS3"
check "last row of CSV not dropped (4 fastq)" test "$(count_files "${ACTIVE_DATA_DIR}/${DS3}" '*.fastq.gz')" -eq 4
check "input CSV left untouched" cmp "${ROOT}/no_newline.csv" "${ROOT}/no_newline.orig"
DSM="${ACTIVE_DATA_DIR}/TestProj_matching_20240117"
step "activates tarball with spaces in group" 0 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/matching.csv" -d TestProj_matching_20240117
check "matching reads extracted (4 fastq)" test "$(count_files "$DSM" '*.fastq.gz')" -eq 4
check "dot in sample name matched literally" test -f "${DSM}/s.1_R1.fastq.gz" -a ! -e "${DSM}/sX1_R1.fastq.gz"
check "sample name matched as substring" test -f "${DSM}/sample10_R1.fastq.gz"
check "read file name with space extracted" test -f "${DSM}/my sample_R1.fastq.gz"

# Study creation: directory layout and symlinks into active data
printf "\ncreate_study.sh\n"
step "fails on unknown project" 1 "" bash "${SCRIPTS}/create_study.sh" -p nope -d "$DS1"
step "creates study one" 0 "" bash "${SCRIPTS}/create_study.sh" -p "$PROJ" -d "$DS1"
check "study subdirs created" test -d "${PROJ_DIR}/${PROJ}/${STUDY1}/sandbox" -a -d "${PROJ_DIR}/${PROJ}/${STUDY1}/results" -a -d "${PROJ_DIR}/${PROJ}/${STUDY1}/scripts"
check "4 data symlinks" test "$(count_files "${PROJ_DIR}/${PROJ}/${STUDY1}/data" '*.fastq.gz')" -eq 4
step "creates study two" 0 "" bash "${SCRIPTS}/create_study.sh" -p "$PROJ" -d "$DS2"
step "creates study three" 0 "" bash "${SCRIPTS}/create_study.sh" -p "$PROJ" -d "$DS3"
## Study four holds only .fq.gz reads (#71)
step "activates .fq.gz reads" 0 "" bash "${SCRIPTS}/activate_data.sh" -c "${ROOT}/fq.csv" -d "$DS4"
step "creates study four" 0 "" bash "${SCRIPTS}/create_study.sh" -p "$PROJ" -d "$DS4"
check "2 .fq.gz data symlinks" test "$(count_files "${PROJ_DIR}/${PROJ}/${STUDY4}/data" '*.fq.gz')" -eq 2
check "no literal glob link" test ! -L "${PROJ_DIR}/${PROJ}/${STUDY4}/data/*fastq.gz"
step "refuses existing study" 1 "" bash "${SCRIPTS}/create_study.sh" -p "$PROJ" -d "$DS1"

# Append to an existing study: prompt, conflict check, new reads linked
printf "\nactivate_data.sh -a (append)\n"
step "append cancelled on 'n'" 1 "n\n" bash "${SCRIPTS}/activate_data.sh" -a -p "$PROJ" -c "${ROOT}/study1_append.csv" -d "$DS1"
step "append rejects conflicting samples" 1 "y\n" bash "${SCRIPTS}/activate_data.sh" -a -p "$PROJ" -c "${ROOT}/study1.csv" -d "$DS1"
step "appends sampleC" 0 "y\n" bash "${SCRIPTS}/activate_data.sh" -a -p "$PROJ" -c "${ROOT}/study1_append.csv" -d "$DS1"
check "6 fastq files in active data" test "$(count_files "${ACTIVE_DATA_DIR}/${DS1}" '*.fastq.gz')" -eq 6
check "6 data symlinks in study" test "$(count_files "${PROJ_DIR}/${PROJ}/${STUDY1}/data" '*.fastq.gz')" -eq 6
check "data.csv has 3 samples" test "$(tail -n +2 "${PROJ_DIR}/${PROJ}/${STUDY1}/data.csv" | grep -c .)" -eq 3
## Study three was activated from a CSV without a trailing newline: the
## appended row must start on its own line, not be glued to the last one
step "appends to study from CSV without newline" 0 "y\n" bash "${SCRIPTS}/activate_data.sh" -a -p "$PROJ" -c "${ROOT}/study1_append.csv" -d "$DS3"
check "data.csv has 3 samples on separate lines" test "$(tail -n +2 "${PROJ_DIR}/${PROJ}/${STUDY3}/data.csv" | grep -c .)" -eq 3
step "appends .fq.gz reads" 0 "y\n" bash "${SCRIPTS}/activate_data.sh" -a -p "$PROJ" -c "${ROOT}/fq_append.csv" -d "$DS4"
check "4 .fq.gz data symlinks after append" test "$(count_files "${PROJ_DIR}/${PROJ}/${STUDY4}/data" '*.fq.gz')" -eq 4

# Freeze: checks, study packed into the freezer, study and active data
# removed
printf "\nfreeze_study.sh\n"
mv "${RAW_DIR}/run2.tar" "${RAW_DIR}/run2.moved"
step "refuses when a source tarball is missing" 1 "" bash "${SCRIPTS}/freeze_study.sh" -p "$PROJ" -s "$STUDY1"
mv "${RAW_DIR}/run2.moved" "${RAW_DIR}/run2.tar"
check "study kept when source tarball missing" test -d "${PROJ_DIR}/${PROJ}/${STUDY1}"
step "refuses missing freezer dir" 1 "" env ATLAS_CONFIG="${ROOT}/config_no_freezer.sh" bash "${SCRIPTS}/freeze_study.sh" -p "$PROJ" -s "$STUDY1"
check "no file created at freezer path" test ! -e "${ROOT}/no_freezer"
step "freezes study one" 0 "" bash "${SCRIPTS}/freeze_study.sh" -p "$PROJ" -s "$STUDY1"
check "tarball in freezer" test -f "${FREEZE_DIR}/${STUDY1}.tar.gz"
check "study dir removed" test ! -d "${PROJ_DIR}/${PROJ}/${STUDY1}"
check "active data removed" test ! -d "${ACTIVE_DATA_DIR}/${DS1}"

# Thaw: study unpacked and active data re-created from the source tarballs
printf "\nthaw_study.sh\n"
step "thaws study one" 0 "" bash "${SCRIPTS}/thaw_study.sh" -p "$PROJ" -s "$STUDY1"
check "study dir restored" test -d "${PROJ_DIR}/${PROJ}/${STUDY1}"
check "active data restored (6 fastq)" test "$(count_files "${ACTIVE_DATA_DIR}/${DS1}" '*.fastq.gz')" -eq 6
check "freezer tarball removed" test ! -f "${FREEZE_DIR}/${STUDY1}.tar.gz"

# Archive: checks, prompt, sandbox refusal, tarball in archive, cleanup, log
printf "\narchive_study.sh\n"
step "refuses missing archive dir" 1 "y\n" env ATLAS_CONFIG="${ROOT}/config_no_archive.sh" bash "${SCRIPTS}/archive_study.sh" -p "$PROJ" -s "$STUDY2"
check "no file created at archive path" test ! -e "${ROOT}/no_archive"
step "archive cancelled on 'n'" 1 "n\n" bash "${SCRIPTS}/archive_study.sh" -p "$PROJ" -s "$STUDY2"
step "refuses while sandbox present" 1 "y\n" bash "${SCRIPTS}/archive_study.sh" -p "$PROJ" -s "$STUDY2"

# Setup, not a test: archiving refuses while sandbox/ exists
rmdir "${PROJ_DIR}/${PROJ}/${STUDY2}/sandbox"
step "archives study two" 0 "y\n" bash "${SCRIPTS}/archive_study.sh" -p "$PROJ" -s "$STUDY2"
check "archive tarball present" test -f "${ARCHIVE_DIR}/${STUDY2}.tar.gz"
check "archive tarball valid" tar -tzf "${ARCHIVE_DIR}/${STUDY2}.tar.gz"
check "study dir removed" test ! -d "${PROJ_DIR}/${PROJ}/${STUDY2}"
check "active data removed" test ! -d "${ACTIVE_DATA_DIR}/${DS2}"
check "archive logged" grep -q "$STUDY2" "${ARCHIVE_DIR}/archive_log.txt"

# Summary
printf "\n%d passed, %d failed\n" "$pass" "$fail"
if [[ "$fail" -gt 0 ]]; then
    printf "Failed:\n"
    printf "  - %s\n" "${failed_steps[@]}"
    exit 1
fi
