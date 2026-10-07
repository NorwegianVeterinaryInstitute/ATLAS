# archive_study.sh

## Purpose
Archive a study by creating a tarball, transferring it to `ARCHIVE_DIR`, validating checksums, and cleaning up local study data after success.
#### File deletion warning:
The script will delete the local study directory after successful archiving, as well as the connected active data directory in `ACTIVE_DATA_DIR/study_${study_dir}`. This is done by design.

## When To Use
Use this script when a study is finalized and should be moved from active project storage to permanent archive storage.

## Usage
```text
--8<-- "help/archive_study.txt"
```

## Prerequisites
- Config file must exist at:
  - `${ATLAS_CONFIG}`, or
  - `${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh`
- Config file should define:
  - `PROJ_DIR`
  - `ARCHIVE_DIR`
  - `ACTIVE_DATA_DIR`
  - `ARCHIVE_SIZE_THRESHOLD_GB` (optional, defaults to 250)
- Project directory exists under `PROJ_DIR`.
- Study directory exists under `PROJ_DIR/project_name`.
- Study not already archived in `ARCHIVE_DIR`.

## Required Study Structure Before Archiving
The script enforces:
- `sandbox` directory must be removed
- `results` directory must exist
- `data` directory must exist
If these conditions are not met, archiving is stopped.

## Outputs
In archive storage:
- `ARCHIVE_DIR/study_dir.tar.gz`
- `ARCHIVE_DIR/archive_log.txt` (appended)
In project storage:
- `PROJ_DIR/project_name/archive_log.txt` (appended)

## Error messages
- Error: Missing required argument `-s` or `-p`
  - Required flag was not provided.
- Config not found: ...
  - Config file was not found at resolved path.
- Supplied project directory does not exist.
  - Project path under `PROJ_DIR` not found.
- Supplied study directory does not exist.
  - Study path not found.
- Study already archived. Please verify name of the study.
  - Same archive already exists in `ARCHIVE_DIR`.
- The `sandbox` directory is still present in the study.
  - Cleanup requirement not satisfied.
- The `results` directory is not present in the study.
  - Required structure missing.
- The `data` directory is not present in the study.
  - Required structure missing.
- Error: Archive verification failed. Deleting corrupt archive.
  - Tarball could not be read.
- rsync failed with exit code X
  - Transfer failed; stderr details follow in output.
- Error: Checksums not equal. Please check files manually.
  - Transfer integrity check failed.
