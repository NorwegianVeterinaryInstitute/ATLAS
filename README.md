# Saga Scripts
Repository for the main scripts used on Saga/NIRD.

## How to use

### Activate
The activation script will unpack files from NIRD
based on a user-supplied list, and send them to a
user-defined directory at `/cluster/shared/vetinst/datasets/wgs`.

To use:
```
activate <csv> project_experiment_YYYYMMDD
```

The naming convention of the output directory is mandatory.
No underscores are allowed within each element in the name.

The supplied csv file looks like this:

```
sampleid1,tarballName
sampleid2,tarballName
```

The script will look for the sampleID within the tarball
and identify the exact file names from that. It will only
match to read files ending in either `fastq.gz` or `fq.gz`.
If a file is not found, they will be reported in an output 
file in the resulting output directory, called `missing_files.csv`.

The resulting output directory will look like this:

```
project_experiment_YYYYMMDD
|
|- sampleid1_R1.fastq.gz
|- sampleid1_R2.fastq.gz
|- sampleid2_R1.fastq.gz
|- sampleid2_R2.fastq.gz
|- info.txt
|- md5sums.txt
|- (missing_files.csv)
```

### Create project
The create project script will generate a project directory
in `~/nn9305k/projects` and populate it with necessary
log files. The project directory is the top-most directory that
is used to gather all experiment directories related to the project.

Note: The project directory is only used for practical purposes, to 
make it easier to find the specific experiment directories for that
project. The topmost project directory created with this script will 
be used as the topmost directory on NIRD when archiving experiments.

Usage:

```
create_project.sh projectNumber_projectName
```

Note that the two elements, projectNumber and projectName are mandatory.
No underscores are allowed within each of these elements.
The project number should preferably be the internal NVI project number, but
can also be NRC project numbers or others.
If no project number exists, please use other information that is useful
or that helps other users identify which project this directory is 
connected to.

Example:
If the project name is "Cool Project" and the internal project number is
"11111", then the resulting naming convention would be:

`11111_coolProject`

Always check if there is an existing project directory for your project
before you use this script. The script will stop if it detects that the
directory you want to create already exists. However it will not detect
deviations of the same project name. Thus, make sure you have checked if
a directory has already been created for your project.
