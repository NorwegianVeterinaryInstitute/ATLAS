# Saga Scripts
Repository for the main scripts used on Saga/NIRD.

## How to use

### Activate
The activation script will unpack files from NIRD
based on a user-supplied list, and send them to a
user-defined directory at `/cluster/shared/vetinst/datasets/wgs`.

To use:
```
activate <path_to_csv> project_experiment_YYYYMMDD
```

The naming convention of the output directory is mandatory.
No underscores are allowed within each element in the name.

The supplied csv file looks like this:

```
sampleid1,tarballName
sampleid2,tarballName
```

The script will look for the sampleID within the tarball
and identify the exact file names from that. If a file is
not found, they will be reported in an output file in the
resulting output directory, called ``missing_files.csv`.

