# activate_data.sh

## Purpose
The script is used to activate data for analysis, or in other words, transferring raw sequencing data from a storage directory to `ACTIVE_DATA_DIR`, defined in the configuration.

## When to use
Use this script to populate an active data directory for a study, either:

- Initial activation (new output directory, before using `create_study.sh`)
- Append mode (`-a`) to add new data to an existing study/data directory pair

## Usage
```text
--8<-- "help/activate_data.txt"
```

## Naming Rules (`-d`)
`OUTPUT_DIR` must follow:

- `<project_study_YYYYMMDD>`
- Project and study parts may contain letters, numbers, and hyphen
- No underscores inside project/study parts
- Date must be exactly eight digits and a real date.

Regex used:
```bash
^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{8})$
```

## Input CSV
The input csv has two columns:
`sample_name,/path/to/tarball.tar`

Tarballs must be uncompressed and named `*.tar`.

A header line is optional, and its column names are free. The first line is treated as a header when its second field does not end in `.tar`; the script prints the line it skips. The input file itself is never changed.

Supported patterns:

- Quoted or unquoted fields
- Multiple tarballs in second field, comma separated and under one quote
- Empty lines
- Windows (CRLF) line endings and a missing newline after the last line

Examples:

```
sample1,/path/to/tarball1.tar
"sample2","/path/to/tarball2.tar"
"sample3","/path/to/tarball1.tar,/path/to/tarball3.tar"
```

If several tarballs are present on the same line, the respective sampleID will be searched for in all tarballs on that line.

## Sample name matching
A read file (`*.fastq.gz` or `*.fq.gz`) is taken for a sample when its file name contains the sample name anywhere. Directory names inside the tarball are ignored, and characters such as `.`, `+` or `[` in the sample name are matched literally.

This lets you choose how specific a sample name is, but you are responsible for keeping names unambiguous within a tarball. For example, with this tarball:

```
tarball1.tar
- sample1_L001_R1.fastq.gz
- sample1_L001_R2.fastq.gz
- sample1_L002_R1.fastq.gz
- sample1_L002_R2.fastq.gz
- sample10_L001_R1.fastq.gz
- sample10_L001_R2.fastq.gz
```

the sample name `sample1` matches the `sample10` reads too. Use a more specific name, such as `sample1_L001`, with one line per lane:

```
sample1_L001,/path/to/tarball1.tar
sample1_L002,/path/to/tarball1.tar
sample10_L001,/path/to/tarball1.tar
```

## Prerequisites

- Config file must exist at:
    - `${ATLAS_CONFIG}`, or
    - `${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh`
- Config file should define at least:
    - `ACTIVE_DATA_DIR`
    - `PROJ_DIR`
- `lib.sh` must exist and is sourceable
- Required external tools are available (`tar`,`dos2unix`,`sha512sum`, etc.)

## Output
### Non-append mode
Creates `${ACTIVE_DATA_DIR}/{OUTPUT_DIR}` and populates:

- `fastq.gz`/`fq.gz` files: The actual read files extracted from the tarballs
- `sha512sums.txt`: sha512sum-values for all read files
- `transferred_reads.txt`: A list of the reads transferred
- `info.txt`: Who activated the data and when
- `data.csv`: The samples from the input csv, with the header `sample,tarball`

Every sample must have reads in its tarball(s); this is checked before the output directory is created. If a read still cannot be extracted, the script removes the output directory it created, so you can fix the problem and rerun.

### Append mode
Updates existing active/study directories and adds:

- New `fastq.gz`/`fq.gz` files
- Updated `sha512sums.txt`
- `appended_reads.txt`: A list of the appended reads
- `append_log.txt`: Who appended the data and when
- Updated `data.csv`

The reads are extracted into a temporary `.append_in_progress` directory inside the active data directory and moved into place only when all of them were extracted. If the append fails, the active data directory and the study are left as they were.

And copies updated files to the connected study directory at:
`${PROJ_DIR}/${PROJECT_NAME}/study_${OUTPUT_DIR}`

## Error Messages

- Error: Missing required argument <flag>...
    - Missing required argument to the respective flag.
- Error: Append mode requires `-p`...
    - `-a` used without `-p`
- Error: CSV file not found: <path>
    - The file given with `-c` does not exist.
- Error: No samples found in CSV file: <path>
    - The CSV is empty, or holds only a header or empty lines.
- Config not found: <path>
    - Config file not found at resolved location.
- Error: Invalid date...
    - Date part of `-d` is not a real `YYYYMMDD`.
- Output directories do not exist, cannot append
    - Append mode target paths missing.
- Error: these sample/tarball combinations already exist:...
    - Append input conflicts with existing data.csv.
- Error: these read files would overwrite each other or existing reads:...
    - Two reads share a file name (from two tarballs, two directories in one tarball, or a sample name contained in another), or, in append mode, a read is already in the output directory. Nothing is changed.
- Error: Sample <name> not found in <tarball>
    - The sample has no reads in its tarball(s): check the sample name. Nothing is changed.
- Error: Expected N reads, but transferred M
    - Some reads were not extracted. Earlier errors give the cause. Nothing is kept: the new output directory is removed, and an append leaves the existing directory unchanged.
- Error: Could not create .../.append_in_progress...
    - An earlier append was interrupted. Remove that directory and rerun.
