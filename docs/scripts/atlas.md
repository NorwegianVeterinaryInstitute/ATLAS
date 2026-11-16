# atlas.sh

## Purpose
`atlas.sh` is a single entry point for the ATLAS scripts. `atlas COMMAND [ARGS]` runs `COMMAND.sh` from the `scripts` directory with the same arguments, so these two calls do the same:

```
atlas create_project -p 12345_MyProject
scripts/create_project.sh -p 12345_MyProject
```

The arguments, prompts, output and exit status are those of the command's script. See the page of each script for details.

## When To Use
Use it instead of calling the scripts one by one, after linking it into a `bin` directory as `atlas` (see [Installation](../installation-and-configuration.md)). The individual scripts still work as before.

## Usage
```text
--8<-- "help/atlas.txt"
```

## Prerequisites
- The script must be in the same directory as the other ATLAS scripts. A link to it from a `bin` directory works.
- No config file is needed for `atlas.sh` itself. The commands need one as described on their pages.

## Error messages
- Unknown command: `<command>`
    - `COMMAND` is not one of the commands listed in the help message.
- Help message, exit status 1
    - No `COMMAND` given.
