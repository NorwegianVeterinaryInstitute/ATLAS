# freeze_study.sh

## Purpose
Freeze a study by packaging it into a tarball, copying it to freezer storage, verifying integrity, and removing local study/data after successful transfer. Note: This is NOT the same as permanent archiving of a project. Please see [archive_study.sh](archive_study.md) for more information on archiving studies.
#### File deletion warning:
The script will delete the local study directory after successful freeze, as well as the connected active data directory in `ACTIVE_DATA_DIR/study_${study_dir}`. This is done by design, as the data will be reconstituted when thawing the study with `thaw_study.sh`. The script asks for confirmation first; use `-y` to skip the prompt in scripts.

#### Source tarballs must stay in place
The frozen study holds links to the reads, not the reads themselves. Thawing extracts the reads again from the source tarballs listed in the study's `data.csv`, so the script checks that they all exist before freezing, and refuses otherwise.

## When To Use
Use this script when a study is paused long-term and should be moved out of active project storage into freezer storage.

## Usage
```text
--8<-- "help/freeze_study.txt"
```

## Prerequisites

- Config file must exist at:
    - `${ATLAS_CONFIG}`, or
    - `${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh`
- Config file should define:
    - `PROJ_DIR`
    - `ACTIVE_DATA_DIR`
    - `FREEZE_DIR`
- Project directory exists under `PROJ_DIR`.
- Study directory exists under `PROJ_DIR/project_name`.
- `FREEZE_DIR` exists.
- Destination tarball does not already exist in `FREEZE_DIR`.
- The source tarballs listed in the study's `data.csv` exist.

## Output

- Freezer archive: `FREEZE_DIR/study_dir.tar.gz`
- Updated study-level log, inside the archive: `PROJ_DIR/project_name/study_dir/freeze_log.txt`
- Updated project log: `PROJ_DIR/project_name/freeze_log.txt`
- Updated freezer log: `FREEZE_DIR/freeze_log.txt`

## Error messages

- Error: Missing required argument `-p` or `-s`
    - Required flag not provided.
- Config not found: ...
    - Config path invalid or missing.
- Supplied project directory does not exist.
    - Project path under `PROJ_DIR` not found.
- Supplied study directory does not exist.
    - Study path under project not found.
- Freeze directory does not exist: ...
    - `FREEZE_DIR` is wrong or not mounted.
- Study already frozen. Please verify name of the study.
    - Target archive already exists in FREEZE_DIR.
- Error: Tarball not found: ... / Thawing needs the source tarballs. Not freezing.
    - A source tarball in the study's `data.csv` has moved or been deleted.
- Error: Sample <name> not found in ...
    - A sample in the study's `data.csv` has no reads in its tarball(s), so they could not be restored. Studies activated before missing samples stopped activation can have such rows; remove them from `data.csv` (in the study and in `ACTIVE_DATA_DIR`) and rerun.
- Freezing cancelled.
    - The prompt was not answered with `y`.
- Error: Archive verification failed. Deleting corrupt archive.
    - Tarball could not be read.
- rsync failed with exit code X
    - Transfer failed; stderr details are printed.
- Error: Checksums not equal. Please check files manually.
    - Post-transfer integrity check failed.
