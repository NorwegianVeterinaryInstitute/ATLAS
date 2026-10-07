# create_project.sh

## Purpose
The script will generate a directory in `PROJ_DIR`, defined in the configuration. This directory is conceptually the topmost directory that is used to group all studies related to the project. The script will also populate the project directory with metadata files.

## When To Use
Use this script when starting a new project before creating studies or activating data.

## Usage
```text
--8<-- "help/create_project.txt"
```

## Naming rules
`PROJECT_NAME` must follow:
- Exactly two parts separated by one underscore: `string_projectName`
- Allowed characters in each part: letters (`a-z`, `A-Z`), numbers (`0`-`9`), and hyphen (`-`)
- Underscores within each part is not allowed

Regex used by script:
```
^([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)$
```

Examples:
- Valid: `12345_MyProject`
- Valid: `norway_ringtest`
- Invalid: `12345_my_project`

## Prerequisites
- Config file must exist at:
  - `${ATLAS_CONFIG}`, or
  - `${XDG_CONFIG_HOME:-$HOME/.config}/atlas/config.sh`
- Config file must define:
  - `PROJ_DIR`
  - `TEMPLATE_DIR`
- Template file must exist:
  - `${TEMPLATE_DIR}/project_readme.txt`

## Output
Created in `${PROJ_DIR}/${PROJECT_NAME}`:
- `creation.txt`
- `README.txt` (copied from `${TEMPLATE_DIR}/project_readme.txt`)

## Error messages
- Error: Missing required argument `-p`
  - Required flag (`-p`) not provided.
- Config not found: <path>
  - Config file not found at resolved location.
- Error: Project README template not found at <path>
  - Template file is missing.
- Error: Input must follow the format `string_projectName`
  - Input did not match required naming format.
- Output directory already exists. Please choose a different name
  - Project directory already exists at destination path.
