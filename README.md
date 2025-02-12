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
