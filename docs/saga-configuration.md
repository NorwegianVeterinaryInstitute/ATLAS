# Example setup: Saga
This page shows how ATLAS can be set up for a group of users on a shared HPC cluster, using [Saga](https://documentation.sigma2.no/hpc_machines/saga.html) and NIRD as an example. Replace the placeholders with your own values:

- `YOUR_SAGA_PROJECT`: your Saga project code, e.g. `nn1234k`
- `YOUR_NIRD_PROJECT`: your NIRD storage project code, e.g. `NS1234K`
- `YOUR_GROUP`: your group's directory under `/cluster/shared`

## Shared configuration
All users in a group should use the same directories, so the group keeps one configuration file in a shared location instead of one per user. Each user then points ATLAS to it with `XDG_CONFIG_HOME` (see [Configuration](installation-and-configuration.md#configuration)).

For example, with the shared configuration directory `/cluster/projects/YOUR_SAGA_PROJECT/.config/`, the configuration file is `/cluster/projects/YOUR_SAGA_PROJECT/.config/atlas/config.sh`.

## Directory paths
In this example, the project and active data directories are on Saga's project storage, and the freeze and archive directories are on NIRD:

```
PROJ_DIR="/cluster/projects/YOUR_SAGA_PROJECT/projects"
ACTIVE_DATA_DIR="/cluster/shared/YOUR_GROUP/active_data"
FREEZE_DIR="/nird/datapeak/YOUR_NIRD_PROJECT/study_freezer"
ARCHIVE_DIR="/nird/datalake/YOUR_NIRD_PROJECT/study_archive"
```

## User setup
Each user sets `XDG_CONFIG_HOME` in their `$HOME/.bashrc` file.

Open your `.bashrc` file in nano:

```
nano $HOME/.bashrc
```

Add the following line at the end of the file, using your group's shared configuration directory:

```
export XDG_CONFIG_HOME=/cluster/projects/YOUR_SAGA_PROJECT/.config/
```

Save the file and log out and back in. ATLAS now uses the shared configuration.

!!! note
    `XDG_CONFIG_HOME` is also read by other programs that follow the XDG convention, so they will look for their configuration in the shared directory too.
