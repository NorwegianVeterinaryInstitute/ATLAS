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
The input csv is expected to have two columns with headers. Header names are irrelevant. Expected columns:
`sample_name,path/to/tarball.tar`

Supported patterns:
- Quoted or unquoted fields
- Multiple tarballs in second field, comma separated and under one quote
- Empty lines

Examples:

```
sample1,/path/to/tarball1.tar
"sample2","/path/to/tarball2.tar"
"sample3","/path/to/tarball1.tar,/path/to/tarball3.tar"
```

If several tarballs are present on the same line, the respective sampleID will be searched for in all tarballs on that line.

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
- `data.csv`: A copy of the input csv file
- `missing_samples.csv`: A list of samples not found the tarball(s)

### Append mode
Updates existing active/study directories and adds:
- New `fastq.gz`/`fq.gz` files
- Updated `sha512sums.txt`
- `appended_reads.txt`: A list of the appended reads
- `append_log.txt`: Who appended the data and when
- Updated `data.csv`
- Updated `missing_samples.csv`, if relevant

And copies updated files to the connected study directory at:
`${PROJ_DIR}/${PROJECT_NAME}/study_${OUTPUT_DIR}`

## Error Messages
- Error: Missing required argument <flag>...
  - Missing required argument to the respective flag.
- Error: Append mode requires `-p`...
  - `-a` used without `-p`
- Config not found: <path>
  - Config file not found at resolved location.
- Error: Invalid date...
  - Date part of `-d` is not a real `YYYYMMDD`.
- Output directories do not exist, cannot append
  - Append mode target paths missing.
- Error: these sample/tarball combinations already exist:...
  - Append input conflicts with existing data.csv.
