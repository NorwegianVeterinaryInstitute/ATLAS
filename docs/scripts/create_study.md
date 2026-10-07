# create_study.sh

## Purpose
Create a new study directory inside an existing project and connect it to an already activated data directory.

## When To Use
Use this script after:

- A project has been created (`create_project.sh`)
- Data has been activated (`activate_data.sh`)
The script will create the study structure and links FASTQ files from active data.

## Usage
```text
--8<-- "help/create_study.txt"
```

## Prerequisites
- Config file must exist at:
  - `${ATLAS_CONFIG}`, or
  - `${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh`
- Config file should define at least:
  - `PROJ_DIR`
  - `ACTIVE_DATA_DIR`
  - `TEMPLATE_DIR`
- Required directories/files must already exist:
  - `${PROJ_DIR}/${project_name}`
  - `${ACTIVE_DATA_DIR}/${data_dir}`
  - `${TEMPLATE_DIR}/study_readme.txt`
- Activated data directory should contain:
  - `info.txt`
  - `data.csv`
  - `sha512sums.txt`
  - `transferred_reads.txt`
  - `fastq.gz`,`fq.gz` files

## Output
A study directory will be created under `${PROJ_DIR}/${PROJECT_NAME}`, with the naming convention: `study_${DATA_DIR}`. This directory will be populated with the following files:
- `README.txt` from the template directory
- `data_info.txt` copied from data directory `info.txt`
- `data.csv`
- `sha512sums.txt`
- `transferred_reads.txt`
- `data/` with symlinks to the `fastq.gz`/`fq.gz` files in the data directory
- `sandbox/`
- `results/`
- `scripts/`

## Error messages
- Error: Missing required argument -d (data directory name).
  - `-d` not provided.
- Error: Missing required argument -p (project directory name).
  - `-p` not provided.
- Config not found: <path>
  - Config file missing at resolved location.
- Supplied project directory does not exist.
  - Project directory under `PROJ_DIR` not found.
- Supplied data directory does not exist.
  - Data directory under `ACTIVE_DATA_DIR` not found.
- Output study directory already exists.
  - Target study path already exists.
