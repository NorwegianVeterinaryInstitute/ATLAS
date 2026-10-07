# thaw_study.sh

## Purpose
Restore a previously frozen study from freezer storage back into a project directory, verify transfer integrity, reconstitute active data, and validate read checksums. Reconstituted data validation depends on consistent `data.csv` and `sha512sums.txt` contents across freeze/thaw lifecycle.

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
- Frozen tarball exist in `FREEZE_DIR`'
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
- rsync failed with exit code X
  - Transfer failed; stderr output is printed.
- Error: Checksums not equal. Please check files manually.
  - Archive changed or corrupted during transfer.
- sha512sums not equal, please check the following reads:
  - Restored read files do not match expected checksums.
