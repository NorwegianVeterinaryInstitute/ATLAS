# check_dependencies.sh

## Purpose
The script checks that a system has the external tools the ATLAS scripts use. It reads the other scripts to find every tool they call by absolute path (`/usr/bin/...`) and checks that each one exists and is executable. It also checks that `gzip` is on `PATH`, since `tar` starts it by name, and that `rsync`, `sha512sum` and `dos2unix` meet their minimum versions.

## When To Use
Use this script after installing ATLAS on a new system, and when a script fails with "No such file or directory" for a tool.

## Usage
```text
--8<-- "help/check_dependencies.txt"
```

## Prerequisites
- The script must be in the same directory as the other ATLAS scripts. A link to it from a `bin` directory works.
- No config file is needed.

## Output
One line per tool, with its status:
- `ok`: the tool is installed (with its version, where a minimum version applies)
- `missing`: the tool is not found at its path, or `gzip` is not on `PATH`
- `too old`: the tool is older than the minimum version

## Error messages
- Error: `<n>` tool(s) missing or too old.
  - One or more tools are listed as `missing` or `too old`. Install them or update them in `/usr/bin`.
- Error: No tools found in scripts in `<path>`.
  - The script was not run from the ATLAS `scripts` directory.
