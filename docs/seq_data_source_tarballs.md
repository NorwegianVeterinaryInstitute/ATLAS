# Sequencing data and source tarballs

ATLAS activates sequencing reads from source tarballs and keeps a record of
where those tarballs came from. That record is important beyond the initial
data transfer: ATLAS uses it to recreate the active data when a frozen study
is thawed. Static tarball storage is therefore highly recommended for ATLAS
to function properly. Also, ATLAS does not change source tarballs in any
way, they are only used as a data source for sequencing data.

## Source tarball format

An input sequencing tarball is a **`.tar` archive** containing
gzipped read files with names ending in `.fastq.gz` or `.fq.gz`. ATLAS looks
inside the archive and extracts matching read files; it does not unpack the
entire source tarball.

The source tarball is distinct from the `.tar.gz` archive that ATLAS creates
when freezing or archiving a study:

| Archive | Purpose | Format |
| --- | --- | --- |
| Source sequencing archive | Supplies read files for activation and reactivation | Uncompressed `.tar` containing `.fastq.gz` or `.fq.gz` files |
| Frozen study archive | Temporarily stores a study for later thawing | ATLAS-created `.tar.gz` |
| Archived study archive | Stores a completed study | ATLAS-created `.tar.gz` |

## Choosing and recording source locations

You can store source tarballs wherever appropriate for your system and
workflow. The paths supplied in the activation CSV must identify files that
the user running activation can read. Use stable, absolute paths
on storage that is expected to remain available; avoid temporary directories
or locations that are routinely renamed, moved, or cleaned up.

ATLAS records the input rows in `data.csv` in the active-data directory and
copies that file into the study directory. The recorded paths are used later
by `thaw_study.sh` when it reactivates the reads. Moving or deleting a source
tarball, changing permissions, or losing access to its storage can therefore
prevent a thaw from restoring the study's active data. The thaw will need the
source tarballs to be readable at the paths recorded in `data.csv`.

## How source data fits into the ATLAS lifecycle

1. **Activate:** `activate_data.sh` reads the CSV, checks that the listed
   tarballs exist, and extracts matching reads into a directory under
   `ACTIVE_DATA_DIR`. It records checksums and transfer metadata alongside
   the reads.
2. **Create a study:** `create_study.sh` creates the study under `PROJ_DIR`.
   Its `data/` directory contains symbolic links to the active read files;
   the reads are not duplicated into the study directory.
3. **Freeze:** `freeze_study.sh` packages and moves the study to `FREEZE_DIR`
   and removes the active-data directory to free space. The source tarballs
   remain external to this process.
4. **Thaw:** `thaw_study.sh` restores the study and uses its `data.csv` to
   reactivate reads from the source tarballs. It then checks the reactivated
   reads against the saved SHA-512 checksums.
5. **Archive:** `archive_study.sh` packages a completed study in
   `ARCHIVE_DIR` and removes the active-data directory. Like freezing, this
   does not make the original source tarballs part of the study archive.

This means the source tarballs are dependencies of future thawing and new studies, 
so keep their recorded paths and the necessary access permissions in place permanently. 
