# thaw_study.sh

## Purpose
Restore a previously frozen study from freezer storage back into a project directory, verify transfer integrity, reconstitute active data, and validate read checksums. Reconstituted data validation depends on consistent `data.csv` and `sha512sums.txt` contents across freeze/thaw lifecycle.

The reads are extracted again from the source tarballs listed in the study's `data.csv`. The source tarballs are checked before anything is copied or unpacked. The tarball in `FREEZE_DIR` is removed, and the thaw logged, only after the restored reads match their checksums. If a later step fails, the frozen copy is kept and the study and active data directories created by the run are removed, so you can fix the problem and rerun.

## When to use
Use this script when you need a frozen study available again for analysis or archiving.

## Usage
```text
--8<-- "help/thaw_study.txt"
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
- Study directory does not exist under `PROJ_DIR/project_name`
- Active data directory for the study does not exist under `ACTIVE_DATA_DIR`
- Frozen tarball exists in `FREEZE_DIR`
- Source tarballs listed in the study's `data.csv` exist at the same paths
- Script dependency exists: `activate_data.sh`

## Outputs

- Restored study directory at `PROJ_DIR/project_name/study_dir`
- Updated freeze log in restored study
- Updated project freeze log
- Updated freezer thaw log
- Recreated active data directory under `ACTIVE_DATA_DIR`

# Error messages

- Error: Missing required argument `-s` or `-p`
    - Required flag not provided.
- Config not found: ...
    - Config path could not be resolved.
- Supplied project directory does not exist.
    - Project path under PROJ_DIR not found.
- Study already thawed. Please verify name of the study.
    - Study directory already exists in project.
- Frozen study not found: ...
    - No tarball for the study in `FREEZE_DIR`.
- Active data directory already exists: ...
    - The study's reads are already in `ACTIVE_DATA_DIR`.
- Error: Could not read <study>/data.csv from ...
    - The frozen tarball is damaged or has no `data.csv`.
- Error: Tarball not found: ... / Thawing needs the source tarballs. Nothing was changed.
    - A source tarball listed in the study's `data.csv` has moved or been removed.
- Error: Could not restore the study data.
    - `activate_data.sh` failed; its output gives the cause.
- Thaw failed. Removed ... and ...; the frozen study is kept at ...
    - Printed after any failure once copying has started. Fix the problem and rerun.
- rsync failed with exit code X
    - Transfer failed; stderr output is printed.
- Error: Checksums not equal after transfer.
    - Archive changed or corrupted during transfer.
- sha512sums not equal, please check the following reads:
    - Restored read files do not match expected checksums.
