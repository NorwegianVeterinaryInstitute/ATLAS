# Testing

The `tests/e2e.sh` script runs the full ATLAS lifecycle end to end against dummy data: `create_project -> activate_data -> create_study -> append -> freeze_study -> thaw_study -> archive_study`, plus a set of expected-failure cases (invalid names and dates, missing tarballs, existing directories, append conflicts, cancelled prompts, sandbox still present).

The script creates a throwaway directory containing dummy tarballs of gzipped FASTQ files, README templates and a config file, and points ATLAS_CONFIG at it. Real project, data, freeze and archive locations are never touched.

Examples:
```
tests/e2e.sh                # run in $TMPDIR (or /tmp), clean up afterwards
tests/e2e.sh -d ~/tmp -k    # run in ~/tmp and keep the test directory for inspection
tests/e2e.sh -v             # print the output of every step
```

!!! danger "Caution"
    On systems where /tmp is not writable (e.g. Saga), use a directory you own: -d ~/tmp

Requirements: `bash`, `tar`, `gzip`, `rsync`, `dos2unix` and `sha512sum`. The scripts call these tools by absolute path (`/usr/bin/...`), so they must be installed there.

The script exits with status 1 if any step fails, and prints the failing step's output. It also runs in CI, on the same triggers as the lint job.